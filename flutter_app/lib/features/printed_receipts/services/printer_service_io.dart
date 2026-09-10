import 'dart:async';
import 'dart:io';

import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service_common.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterService {
  PrinterService() : _bluetoothManager = BluetoothManager.instance;

  final BluetoothManager _bluetoothManager;

  /// Printers discovered from Settings > Printer Settings.
  final Map<String, BluetoothDevice> _discoveredPrinters = {};

  /// All Bluetooth print jobs use the same queue because
  /// BluetoothManager.instance is shared by the whole application.
  static Future<void> _printQueue = Future<void>.value();

  /// Bluetooth permissions only need to be requested once after
  /// they have already been granted.
  static bool _permissionsGranted = false;

  Stream<List<DiscoveredBluetoothPrinter>> get bluetoothPrinters =>
      _bluetoothManager.scanResults.map((devices) {
        final result = <DiscoveredBluetoothPrinter>[];

        for (final device in devices) {
          final address = device.address?.trim();

          if (address == null || address.isEmpty) {
            continue;
          }

          final name = device.name?.trim().isNotEmpty == true
              ? device.name!.trim()
              : address;

          _discoveredPrinters[_normalizeAddress(address)] = device;

          result.add(
            DiscoveredBluetoothPrinter(
              name: name,
              address: address,
            ),
          );
        }

        return result;
      });

  Stream<bool> get isScanning => _bluetoothManager.isScanning;

  Future<void> _requestBluetoothPermissions() async {
    if (_permissionsGranted) {
      return;
    }

    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied = statuses.values.any(
      (status) => status.isDenied || status.isPermanentlyDenied,
    );

    if (denied) {
      throw StateError(
        'Bluetooth permission denied. '
        'Please allow Bluetooth permission for Matka Management '
        'in Android settings.',
      );
    }

    _permissionsGranted = true;
  }

  Future<void> startBluetoothScan() async {
    await _requestBluetoothPermissions();

    try {
      await _bluetoothManager.stopScan();
    } catch (_) {
      // Ignore if no scan is running.
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );

    await _bluetoothManager.startScan();
  }

  Future<void> stopBluetoothScan() async {
    try {
      await _bluetoothManager.stopScan();
    } catch (_) {
      // Ignore scan-stop errors.
    }
  }

  Future<void> printBytes(
    PrinterConfiguration printer,
    List<int> bytes,
  ) async {
    if (bytes.isEmpty) {
      throw StateError(
        'Printer ticket is empty.',
      );
    }

    if (printer.isBluetooth) {
      await _queueBluetoothPrint(
        printer,
        bytes,
      );
      return;
    }

    await _printWifi(
      printer,
      bytes,
    );
  }

  /// Keeps Bluetooth receipts strictly FIFO.
  ///
  /// Receipt 1 -> prints
  /// Receipt 2 -> waits
  /// Receipt 3 -> waits
  ///
  /// This prevents the shared BluetoothManager from receiving
  /// multiple connect/write/disconnect operations simultaneously.
  Future<void> _queueBluetoothPrint(
    PrinterConfiguration printer,
    List<int> bytes,
  ) async {
    final previous = _printQueue;
    final current = Completer<void>();

    _printQueue = current.future;

    try {
      try {
        await previous;
      } catch (_) {
        // Do not block the next receipt if the previous one failed.
      }

      await _printBluetooth(
        printer,
        bytes,
      );
    } finally {
      if (!current.isCompleted) {
        current.complete();
      }
    }
  }

  Future<void> _printBluetooth(
    PrinterConfiguration printer,
    List<int> bytes,
  ) async {
    await _requestBluetoothPermissions();

    final targetAddress = printer.address?.trim() ?? '';

    if (targetAddress.isEmpty) {
      throw StateError(
        'Bluetooth printer address is empty.',
      );
    }

    final normalizedTarget = _normalizeAddress(
      targetAddress,
    );

    /*
     * IMPORTANT:
     *
     * We do NOT scan for every receipt.
     *
     * The printer MAC address is already saved in PrinterConfiguration.
     *
     * If Settings previously discovered the printer, use that device
     * information. Otherwise create a BluetoothDevice directly from
     * the saved MAC address.
     */
    final discoveredDevice =
        _discoveredPrinters[normalizedTarget];

    final bluetoothDevice = BluetoothDevice()
      ..name = discoveredDevice?.name ?? printer.name
      ..address = discoveredDevice?.address ?? targetAddress
      ..type = discoveredDevice?.type ?? 0
      ..connected = false;

    /*
     * Stop an active Settings scan before printing.
     *
     * We do not start a new scan here.
     */
    try {
      await _bluetoothManager.stopScan();
    } catch (_) {
      // Ignore if no scan is running.
    }

    /*
     * Close any old connection.
     *
     * The global print queue guarantees that another print operation
     * is not currently using the BluetoothManager.
     */
    try {
      await _bluetoothManager.disconnect();
    } catch (_) {
      // No existing connection.
    }

    /*
     * CONNECT
     *
     * No artificial 500 ms delay here.
     */
    dynamic connectResult;

    try {
      connectResult = await _bluetoothManager
          .connect(bluetoothDevice)
          .timeout(
            const Duration(seconds: 10),
          );
    } on TimeoutException {
      throw StateError(
        'Bluetooth connection timed out.\n\n'
        'Printer: ${printer.name}\n'
        'Address: $targetAddress',
      );
    } catch (error) {
      throw StateError(
        'Bluetooth connection failed: $error',
      );
    }

    if (connectResult is bool && connectResult == false) {
      throw StateError(
        'Bluetooth connection was rejected by the printer.',
      );
    }

    /*
     * The connection is now ready.
     *
     * Only a very short delay is kept because your printer already
     * works reliably with the direct Bluetooth method.
     */
    await Future<void>.delayed(
      const Duration(milliseconds: 200),
    );

    try {
      /*
       * SEND ESC/POS DATA DIRECTLY TO THE PRINTER.
       */
      await _bluetoothManager
          .writeData(bytes)
          .timeout(
            const Duration(seconds: 10),
          );
    } on TimeoutException {
      throw StateError(
        'Bluetooth printer accepted the connection '
        'but writing the receipt timed out.',
      );
    } catch (error) {
      throw StateError(
        'Failed to send data to Bluetooth printer: $error',
      );
    } finally {
      /*
       * Keep this short delay so the complete ESC/POS ticket has
       * time to leave the Bluetooth socket before disconnecting.
       */
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      try {
        await _bluetoothManager.disconnect();
      } catch (_) {
        // Ignore disconnect errors.
      }
    }
  }

  String _normalizeAddress(String? address) {
    return (address ?? '')
        .trim()
        .toUpperCase()
        .replaceAll('-', ':');
  }

  Future<void> _printWifi(
    PrinterConfiguration printer,
    List<int> bytes,
  ) async {
    final host = printer.host?.trim() ?? '';

    if (!_isValidHost(host) ||
        printer.port < 1 ||
        printer.port > 65535) {
      throw const FormatException(
        'Invalid IP/hostname or TCP port.',
      );
    }

    Socket? socket;

    try {
      socket = await Socket.connect(
        host,
        printer.port,
        timeout: const Duration(seconds: 8),
      );

      socket.add(bytes);

      await socket.flush().timeout(
        const Duration(seconds: 8),
      );
    } on SocketException catch (error) {
      throw StateError(
        'Wi-Fi connection failed: ${error.message}',
      );
    } on TimeoutException {
      throw StateError(
        'TCP timeout while contacting the printer.',
      );
    } finally {
      await socket?.close();
      socket?.destroy();
    }
  }

  bool _isValidHost(String host) {
    if (host.isEmpty || host.contains(RegExp(r'\s'))) {
      return false;
    }

    final ip = InternetAddress.tryParse(host);

    if (ip != null) {
      return true;
    }

    return RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9.-]*$',
    ).hasMatch(host);
  }

  Future<void> dispose() async {
    /*
     * Do not disconnect the shared BluetoothManager here.
     *
     * The active print operation owns its connection and disconnects
     * after the ticket is sent.
     */
    try {
      await stopBluetoothScan();
    } catch (_) {}
  }
}