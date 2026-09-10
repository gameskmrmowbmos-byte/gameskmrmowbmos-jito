import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service_common.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterService {
  PrinterService() : _bluetoothManager = BluetoothManager.instance;

  final BluetoothManager _bluetoothManager;
  static bool _bluetoothPermissionsReady = false;

  /// Printers discovered from the printer settings screen.
  final Map<String, BluetoothDevice> _discoveredPrinters = {};

  /// Ensures that only one Bluetooth print operation runs at a time.
  ///
  /// This is static because BluetoothManager.instance is shared by all
  /// PrinterService instances.
  static Future<void> _printQueue = Future<void>.value();

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
    if (_bluetoothPermissionsReady) return;

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

    _bluetoothPermissionsReady = true;
  }

  Future<void> startBluetoothScan() async {
    await _requestBluetoothPermissions();

    try {
      await _bluetoothManager.stopScan();
    } catch (_) {
      // Ignore if no scan is running.
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
      // Ignore scan-stop errors.
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

  /// Adds Bluetooth printing to a FIFO queue.
  ///
  /// This is important because every PrinterService uses the same
  /// BluetoothManager.instance.
  ///
  /// Example:
  ///
  /// Receipt 1 starts
  /// Receipt 2 waits
  /// Receipt 3 waits
  ///
  /// Receipt 1 finishes
  /// Receipt 2 starts
  /// Receipt 2 finishes
  /// Receipt 3 starts
  Future<void> _queueBluetoothPrint(
    PrinterConfiguration printer,
    List<int> bytes,
  ) async {
    final previous = _printQueue;

    final current = Completer<void>();

    _printQueue = current.future;

    try {
      // Wait for the previous receipt to completely finish.
      debugPrint('[PRINT] Waiting for print queue');
      try {
        await previous;
      } catch (_) {
        // A failed previous print must not block future prints.
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

    final device = _discoveredPrinters[normalizedTarget];

    await stopBluetoothScan();

    // Normal printing uses the saved address directly; discovery belongs to
    // Printer Settings and is only used when its cached device is available.
    final bluetoothDevice = BluetoothDevice()
      ..name = device?.name ?? printer.name
      ..address = device?.address ?? targetAddress
      ..type = device?.type ?? 0
      ..connected = false;
    debugPrint('[PRINT] Starting Bluetooth connection');

    /*
     * Close any previous connection before starting a new one.
     *
     * Because _queueBluetoothPrint() serializes all print operations,
     * this should not interrupt another receipt.
     */
    try {
      await _bluetoothManager.disconnect();
    } catch (_) {
      // No existing connection.
    }

    /*
     * CONNECT
     */
    dynamic connectResult;

    try {
      connectResult = await _bluetoothManager.connect(bluetoothDevice).timeout(
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

    /*
     * Some versions return a boolean.
     * Treat only an explicit false as failure.
     */
    if (connectResult is bool && connectResult == false) {
      throw StateError(
        'Bluetooth connection was rejected by the printer.',
      );
    }
    debugPrint('[PRINT] Bluetooth connected');

    /*
     * Give the SPP connection a moment to become ready.
     */
    await Future<void>.delayed(
      const Duration(milliseconds: 200),
    );

    try {
      /*
       * SEND ESC/POS RECEIPT
       */
      debugPrint('[PRINT] Writing receipt bytes');
      await _bluetoothManager.writeData(bytes).timeout(
            const Duration(seconds: 10),
          );
      debugPrint('[PRINT] Receipt bytes written');
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
       * Give the Android Bluetooth layer time to flush the data.
       */
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      /*
       * Disconnect after the complete ticket has been transmitted.
       */
      try {
        debugPrint('[PRINT] Disconnecting Bluetooth');
        await _bluetoothManager.disconnect();
        debugPrint('[PRINT] Bluetooth disconnected');
      } catch (_) {
        // Ignore disconnect errors.
      }

      /*
       * Allow the Bluetooth socket to settle before the next queued
       * receipt starts.
       */
    }
  }

  String _normalizeAddress(String? address) {
    return (address ?? '').trim().toUpperCase().replaceAll('-', ':');
  }

  Future<void> _printWifi(
    PrinterConfiguration printer,
    List<int> bytes,
  ) async {
    final host = printer.host?.trim() ?? '';

    if (!_isValidHost(host) || printer.port < 1 || printer.port > 65535) {
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
     * Do NOT disconnect the shared BluetoothManager here.
     *
     * A CustomerParchiPrintSession can be disposed while another
     * queued print operation is running.
     *
     * The active print operation itself handles disconnecting.
     */
    try {
      await stopBluetoothScan();
    } catch (_) {}
  }
}
