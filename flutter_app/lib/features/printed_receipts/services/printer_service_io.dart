import 'dart:async';
import 'dart:io';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service_common.dart';
import 'package:permission_handler/permission_handler.dart';

class PrinterService {
  PrinterService()
      : _manager = PrinterBluetoothManager(),
        _bluetoothManager = BluetoothManager.instance;

  final PrinterBluetoothManager _manager;
  final BluetoothManager _bluetoothManager;

  Stream<List<DiscoveredBluetoothPrinter>> get bluetoothPrinters =>
      _manager.scanResults.map(
        (printers) => printers
            .where((printer) => printer.address?.trim().isNotEmpty == true)
            .map(
              (printer) => DiscoveredBluetoothPrinter(
                name: printer.name?.trim().isNotEmpty == true
                    ? printer.name!.trim()
                    : printer.address!,
                address: printer.address!,
              ),
            )
            .toList(),
      );

  Stream<bool> get isScanning => _manager.isScanningStream;

  Future<void> _requestBluetoothPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    if (statuses.values
        .any((status) => status.isDenied || status.isPermanentlyDenied)) {
      throw StateError('Bluetooth permission denied');
    }
  }

  Future<void> startBluetoothScan() async {
    await _requestBluetoothPermissions();
    _manager.startScan(const Duration(seconds: 8));
  }

  Future<void> stopBluetoothScan() async {
    _manager.stopScan();
  }

  Future<void> printBytes(PrinterConfiguration printer, List<int> bytes) async {
    if (bytes.isEmpty) throw StateError('Printer ticket is empty');
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
    _manager.startScan(const Duration(seconds: 5));
    final scanned = await _manager.scanResults
        .firstWhere(
            (items) => items.any((item) => item.address == printer.address))
        .timeout(const Duration(seconds: 8));
    final selected =
        scanned.firstWhere((item) => item.address == printer.address);
    _manager.selectPrinter(selected);
    final result = await _manager.printTicket(bytes, queueSleepTimeMs: 50);
    if (result != PosPrintResult.success) {
      throw StateError('Bluetooth connection failed: ${result.msg}');
    }
  }

  Future<void> _printWifi(
    PrinterConfiguration printer,
    List<int> bytes,
  ) async {
    final host = printer.host?.trim() ?? '';
    if (!_isValidHost(host) || printer.port < 1 || printer.port > 65535) {
      throw const FormatException('Invalid IP/hostname or TCP port');
    }
    Socket? socket;
    try {
      socket = await Socket.connect(
        host,
        printer.port,
        timeout: const Duration(seconds: 8),
      );
      socket.add(bytes);
      await socket.flush().timeout(const Duration(seconds: 8));
    } on SocketException catch (error) {
      throw StateError('Wi-Fi connection failed: ${error.message}');
    } on TimeoutException {
      throw StateError('TCP timeout while contacting the printer');
    } finally {
      await socket?.close();
      socket?.destroy();
    }
  }

  bool _isValidHost(String host) {
    if (host.isEmpty || host.contains(RegExp(r'\s'))) return false;
    final ip = InternetAddress.tryParse(host);
    if (ip != null) return true;
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9.-]*$').hasMatch(host);
  }

  Future<void> dispose() async {
    await stopBluetoothScan();
    await _bluetoothManager.disconnect();
  }
}
