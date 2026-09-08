import 'package:flutter/services.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/printed_receipts/data/printer_models.dart';
import 'package:matka_management/features/printed_receipts/data/printer_store.dart';
import 'package:matka_management/features/printed_receipts/services/escpos_receipt_builder.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service.dart';

class CustomerParchiPrintSession {
  CustomerParchiPrintSession()
      : _service = PrinterService(),
        _builder = EscPosReceiptBuilder();

  static const _systemPrintChannel = MethodChannel('matka_management/system_print');

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
    await _systemPrintChannel.invokeMethod<void>('printHtml', {
      'html': _buildPrintHtml(
        detail,
        overrideParchiNo: overrideParchiNo,
        marketName: marketName,
        ownerName: ownerName,
      ),
    });
  }

  String _buildPrintHtml(
    ReceiptDetail detail, {
    String? overrideParchiNo,
    String? marketName,
    String? ownerName,
  }) {
    final receipt = detail.receipt;
    final createdAt = receipt.createdAt ?? DateTime.now();
    final suppliedMarket = marketName?.trim();
    final storedMarket = receipt.market?.name.trim();
    final market = suppliedMarket?.isNotEmpty == true
        ? suppliedMarket!
        : storedMarket?.isNotEmpty == true
            ? storedMarket!
            : '-';
    final parchi = canonicalParchiNumber(
      overrideParchiNo ?? receipt.receiptNumber,
    );
    final items = detail.consolidatedItems;
    final total = items.fold<num>(0, (sum, item) => sum + item.amount) *
        (receipt.isOtc ? 2 : 1);
    final rows = items.map((item) {
      final number = formatParchiNumber(
        item,
        item.sessionOverride ?? receipt.session,
      );
      final jackpotRows = item.jackpotEntries.map((entry) => '''
        <tr><td class="number">-&gt;${_escape(entry.number)} &gt;</td><td>${_escape(entry.amount)}</td></tr>
      ''').join();
      final marker = item.isBazarSangam
          ? '<tr><td colspan="2"><b>BAZAR</b></td></tr>'
          : item.isMotorPana
              ? '<tr><td colspan="2"><b>MP</b></td></tr>'
              : '';
      return '''
        $marker
        <tr><td class="number">${_escape(number)}</td><td>${_escape(item.effectiveDisplayAmount)}</td></tr>
        $jackpotRows
      ''';
    }).join();
    final owner = ownerName?.trim().isNotEmpty == true
        ? '<div class="center bold">${_escape(ownerName!.trim().toUpperCase())}</div>'
        : '';
    return '''
<!doctype html><html><head><meta name="viewport" content="width=device-width">
<style>
@page { size: 58mm auto; margin: 0; }
body { width: 58mm; margin: 0; padding: 4mm; box-sizing: border-box; font-family: sans-serif; font-size: 11px; color: #000; }
.center { text-align: center; } .right { text-align: right; } .bold { font-weight: bold; }
table { width: 100%; border-collapse: collapse; } td { padding: 1px 0; vertical-align: top; }
td:last-child { text-align: right; white-space: nowrap; } .number { text-align: left !important; word-break: break-word; }
hr { border: 0; border-top: 1px solid #000; margin: 4px 0; }
</style></head><body>
<div class="center bold">PARCHI NO. ${_escape(parchi)}</div>
<div class="right">${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}<br>${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}</div>
$owner
<div class="center bold">${_escape(market.toUpperCase())} - ${_escape(receipt.session)}</div>
<hr><table><tr><th class="number">NUMBER</th><th>AMT</th></tr>$rows</table><hr>
<table><tr><td class="bold">TOTAL</td><td class="bold">${_formatAmount(total)}</td></tr></table>
${receipt.isOtc ? '<div class="center bold">OTC</div>' : ''}
</body></html>''';
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  String _formatAmount(num amount) => amount
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'\.?0+$'), '');

  Future<void> dispose() => _service.dispose();
}

CustomerParchiPrintSession prepareCustomerParchiPrint() {
  return CustomerParchiPrintSession();
}