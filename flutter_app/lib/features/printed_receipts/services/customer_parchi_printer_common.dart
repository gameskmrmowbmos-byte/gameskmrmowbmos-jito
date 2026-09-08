import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service_common.dart';

class CustomerParchiPrintSession {
  const CustomerParchiPrintSession();

  Future<String?> get activePrinterName async => null;

  Stream<List<DiscoveredBluetoothPrinter>> get scanResults =>
      Stream<List<DiscoveredBluetoothPrinter>>.empty();

  Stream<bool> get isScanning => Stream<bool>.value(false);

  void startScan() {}

  Future<void> stopScan() async {}

  Future<void> printTest(PrinterConfiguration printer) async {
    throw UnsupportedError('Thermal printing is unavailable on this platform');
  }

  Future<void> printReceipt(ReceiptDetail detail,
      {String? overrideParchiNo, String? marketName, String? ownerName}) async {
    throw UnsupportedError(
      AppLocalizations.trCurrent(
        'Customer parchi printing is supported in web builds only.',
      ),
    );
  }

  Future<void> dispose() async {}
}

CustomerParchiPrintSession prepareCustomerParchiPrint() {
  return const CustomerParchiPrintSession();
}
