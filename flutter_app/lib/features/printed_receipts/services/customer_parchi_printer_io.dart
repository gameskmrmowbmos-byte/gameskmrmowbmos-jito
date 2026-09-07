import 'package:matka_management/features/entries/data/receipt_models.dart';

import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:matka_management/features/printed_receipts/data/printer_store.dart';
import 'package:matka_management/features/printed_receipts/services/escpos_receipt_builder.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service.dart';

class CustomerParchiPrintSession {
  CustomerParchiPrintSession()
      : _service = PrinterService(),
        _builder = EscPosReceiptBuilder();

  final PrinterService _service;
  final EscPosReceiptBuilder _builder;
  final PrinterStore _store = PrinterStore();

  Future<String?> get activePrinterName async =>
      (await _store.loadActivePrinter())?.name;

  Stream<List<DiscoveredBluetoothPrinter>> get scanResults =>
      _service.bluetoothPrinters;

  Stream<bool> get isScanning => _service.isScanning;

  void startScan() {
    _service.startBluetoothScan();
  }

  void stopScan() {
    _service.stopBluetoothScan();
  }

  Future<void> printTest(PrinterConfiguration printer) async {
    await _service.printBytes(
      printer,
      await _builder.buildTestPrint(printer.name),
    );
  }

  Future<void> printReceipt(
    ReceiptDetail detail, {
    String? overrideParchiNo,
    String? marketName,
    String? ownerName,
  }) async {
    final printer = await _store.loadActivePrinter();
    if (printer == null) {
      throw StateError('No printer configured. Open Printer Settings first.');
    }
    final bytes = await _builder.buildReceipt(
      detail,
      overrideParchiNo: overrideParchiNo,
      marketName: marketName,
      ownerName: ownerName,
    );
    await _service.printBytes(printer, bytes);
  }

  Future<void> dispose() => _service.dispose();
}

CustomerParchiPrintSession prepareCustomerParchiPrint() {
  return CustomerParchiPrintSession();
}
