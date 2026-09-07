import 'dart:async';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';

class CustomerParchiPrintSession {
  CustomerParchiPrintSession();

  final PrinterBluetoothManager _printerManager =
      PrinterBluetoothManager();

  Stream<List<PrinterBluetooth>> get scanResults =>
      _printerManager.scanResults;

  Stream<bool> get isScanning =>
      _printerManager.isScanningStream;

  void startScan() {
    _printerManager.startScan(
      const Duration(seconds: 5),
    );
  }

  void stopScan() {
    _printerManager.stopScan();
  }

  Future<void> printTest(PrinterBluetooth printer) async {
    _printerManager.selectPrinter(printer);

    final profile = await CapabilityProfile.load();

    final generator = Generator(
      PaperSize.mm80,
      profile,
    );

    final bytes = <int>[];

    bytes.addAll(
      generator.text(
        'TEST PRINT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    );

    bytes.addAll(generator.hr());

    bytes.addAll(
      generator.text(
        'KPC307-UEWB-688D',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
        ),
      ),
    );

    bytes.addAll(
      generator.text(
        'Bluetooth OK',
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      ),
    );

    bytes.addAll(generator.feed(3));

    // Your printer has a cutter.
    bytes.addAll(generator.cut());

    final result = await _printerManager.printTicket(
      bytes,
      queueSleepTimeMs: 100,
    );

    if (kDebugMode) {
      debugPrint(
        'Printer result: ${result.msg}',
      );
    }
  }

  Future<void> printReceipt(
    dynamic detail, {
    String? overrideParchiNo,
    String? marketName,
    String? ownerName,
  }) async {
    throw UnimplementedError(
      'Actual Bluetooth receipt printing will be added after the printer connection is tested.',
    );
  }

  void dispose() {
    stopScan();
  }
}

CustomerParchiPrintSession prepareCustomerParchiPrint() {
  return CustomerParchiPrintSession();
}
