import 'dart:async';
import 'dart:io';

import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service_common.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterService {
  PrinterService() : _bluetoothManager = BluetoothManager.instance;

  final BluetoothManager _bluetoothManager;

  /// Cached printers discovered during scanning.
  ///
  /// We keep the actual BluetoothDevice object because printing is done
  /// directly through flutter_bluetooth_basic.
  final Map<String, BluetoothDevice> _discoveredPrinters = {};

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
  }

  Future<void> startBluetoothScan() async {
    await _requestBluetoothPermissions();

    try {
      await _bluetoothManager.stopScan();
    } catch (_) {
      // Ignore stop-scan errors when no scan is running.
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    await _bluetoothManager.startScan();
  }

  Future<void> stopBluetoothScan() async {
    try {
      await _bluetoothManager.stopScan();
    } catch (_) {
      // Ignore stop-scan errors.
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 300),
    );
  }

  Future<void> printBytes(
    PrinterConfiguration printer,
    List<int> bytes,
  ) async {
    if (bytes.isEmpty) {
      throw StateError('Printer ticket is empty.');
    }

    if (printer.isBluetooth) {
      await _printBluetooth(printer, bytes);
      return;
    }

    await _printWifi(printer, bytes);
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

    final normalizedTarget = _normalizeAddress(targetAddress);

    BluetoothDevice? device =
        _discoveredPrinters[normalizedTarget];

    /*
     * If the PrinterService was recreated, the cache may be empty.
     *
     * In that situation we perform a short scan and find the printer
     * using the saved MAC address.
     */
    if (device == null) {
      await stopBluetoothScan();

      await _bluetoothManager.startScan();

      try {
        final scannedDevices = await _bluetoothManager.scanResults
            .firstWhere(
              (devices) => devices.any(
                (item) =>
                    _normalizeAddress(item.address) ==
                    normalizedTarget,
              ),
            )
            .timeout(
              const Duration(seconds: 8),
            );

        final matching = scannedDevices.where(
          (item) =>
              _normalizeAddress(item.address) ==
              normalizedTarget,
        );

        if (matching.isEmpty) {
          throw StateError(
            'Printer "${printer.name}" was not found.',
          );
        }

        device = matching.first;

        _discoveredPrinters[normalizedTarget] = device;
      } on TimeoutException {
        throw StateError(
          'Printer "${printer.name}" was not found.\n\n'
          'Make sure:\n'
          '1. The printer is switched ON.\n'
          '2. Bluetooth is enabled on the phone.\n'
          '3. The printer is paired with the phone.\n'
          '4. The saved printer address is $targetAddress.',
        );
      } finally {
        await stopBluetoothScan();
      }
    }

    await stopBluetoothScan();

    /*
     * Build a fresh BluetoothDevice using the saved printer details.
     *
     * This avoids depending on an old connection state inside the
     * cached device object.
     */
    final bluetoothDevice = BluetoothDevice()
      ..name = device.name ?? printer.name
      ..address = device.address ?? targetAddress
      ..type = device.type ?? 0
      ..connected = false;

    /*
     * Make sure any previous connection is closed before opening
     * a fresh connection.
     */
    try {
      await _bluetoothManager.disconnect();
    } catch (_) {
      // There may not be an existing connection.
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 500),
    );

    /*
     * CONNECT
     *
     * flutter_bluetooth_basic uses the Android Bluetooth SPP
     * connection internally.
     */
    dynamic connectResult;

    try {
      connectResult = await _bluetoothManager
          .connect(bluetoothDevice)
          .timeout(
            const Duration(seconds: 12),
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

    /*
     * Some versions of flutter_bluetooth_basic return a boolean,
     * while others return a dynamic platform result.
     *
     * Only treat an explicit false as failure.
     */
    if (connectResult is bool && connectResult == false) {
      throw StateError(
        'Bluetooth connection was rejected by the printer.',
      );
    }

    await Future<void>.delayed(
      const Duration(milliseconds: 800),
    );

    /*
     * WRITE RAW ESC/POS DATA
     *
     * This is the important change:
     *
     * We are NOT using:
     *
     * PrinterBluetoothManager.printTicket()
     *
     * We directly send the ESC/POS bytes to the Bluetooth printer.
     */
    try {
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
       * Give Android a short moment to flush the Bluetooth output
       * before disconnecting.
       */
      await Future<void>.delayed(
        const Duration(milliseconds: 800),
      );

      try {
        await _bluetoothManager.disconnect();
      } catch (_) {
        // Ignore disconnect errors after successful transmission.
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
    try {
      await stopBluetoothScan();
    } catch (_) {}

    try {
      await _bluetoothManager.disconnect();
    } catch (_) {}
  }
}