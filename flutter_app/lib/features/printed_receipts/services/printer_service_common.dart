import 'package:matka_management/features/printed_receipts/data/printer_models.dart';

class DiscoveredBluetoothPrinter {
  const DiscoveredBluetoothPrinter({required this.name, required this.address});

  final String name;
  final String address;
}

class PrinterService {
  Stream<List<DiscoveredBluetoothPrinter>> get bluetoothPrinters =>
      const Stream.empty();

  Stream<bool> get isScanning => Stream<bool>.value(false);

  Future<void> startBluetoothScan() async {
    throw UnsupportedError(
        'Bluetooth printing is unavailable on this platform');
  }

  Future<void> stopBluetoothScan() async {}

  Future<void> printBytes(PrinterConfiguration printer, List<int> bytes) async {
    throw UnsupportedError(
        'Native printer transports are unavailable on this platform');
  }

  Future<void> dispose() async {}
}
