import 'package:flutter/foundation.dart';
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

  Future<void> stopScan() => _service.stopBluetoothScan();

  /// Test print.
  ///
  /// This sends ESC/POS bytes directly to the selected Bluetooth printer.
  Future<void> printTest(PrinterConfiguration printer) async {
    await _service.printBytes(
      printer,
      await _builder.buildTestPrint(printer.name),
    );
  }

  /// Print the actual customer parchi directly to the configured printer.
  ///
  /// IMPORTANT:
  /// This no longer uses Android's system PrintManager or PDF printing.
  /// The receipt is converted to ESC/POS bytes and sent directly through
  /// Bluetooth/Wi-Fi using PrinterService.
  Future<void> printReceipt(
    ReceiptDetail detail, {
    String? overrideParchiNo,
    String? marketName,
    String? ownerName,
  }) async {
    // Load the printer that is currently configured as active.
    final printer = await _store.loadActivePrinter();

    if (printer == null) {
      throw StateError(
        'No active printer configured.\n\n'
        'Please open Settings > Printer Settings and select a printer.',
      );
    }
    debugPrint(
        '[PRINT] Active printer: ${printer.name} ${printer.address ?? ''}');

    // Build the receipt as ESC/POS bytes.
    final bytes = await _builder.buildReceipt(
      detail,
      overrideParchiNo: overrideParchiNo,
      marketName: marketName,
      ownerName: ownerName,
    );

    if (bytes.isEmpty) {
      throw StateError(
        'Receipt data is empty. Nothing was sent to the printer.',
      );
    }
    debugPrint('[PRINT] Receipt bytes: ${bytes.length}');

    // Send the receipt directly to the configured printer.
    await _service.printBytes(
      printer,
      bytes,
    );
  }

  Future<void> dispose() => _service.dispose();
}

CustomerParchiPrintSession prepareCustomerParchiPrint() {
  return CustomerParchiPrintSession();
}
