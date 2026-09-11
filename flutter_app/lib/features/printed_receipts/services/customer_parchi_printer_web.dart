import 'dart:async';
import 'dart:js_interop';

import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/printed_receipts/services/printer_service_common.dart';
import 'package:web/web.dart' as web;

const _parchiEntriesPerPage = 10;

class CustomerParchiPrintSession {
  const CustomerParchiPrintSession._(this._window);

  final web.Window? _window;

  Future<String?> get activePrinterName async => null;

  Stream<List<DiscoveredBluetoothPrinter>> get scanResults =>
      Stream<List<DiscoveredBluetoothPrinter>>.empty();

  Stream<bool> get isScanning => Stream<bool>.value(false);

  void startScan() {}

  Future<void> stopScan() async {}

  Future<void> dispose() async {}

  Future<void> printTest(Object printer) async {
    throw UnsupportedError('Direct thermal printing is unavailable on the web');
  }

  Future<void> printReceipt(ReceiptDetail detail,
      {String? overrideParchiNo, String? marketName, String? ownerName}) async {
    final target =
        _window ?? web.window.open('', '_blank', 'width=420,height=720');
    if (target == null) {
      throw StateError('Print popup was blocked');
    }

    final document = target.document;
    document.open();
    document.write(
      _buildReceiptHtml(detail, overrideParchiNo, marketName, ownerName).toJS,
    );
    document.close();

    await Future<void>.delayed(const Duration(milliseconds: 250));
    target.focus();
    target.print();
  }
}

CustomerParchiPrintSession prepareCustomerParchiPrint() {
  return CustomerParchiPrintSession._(
    web.window.open('', '_blank', 'width=420,height=720'),
  );
}

String _buildReceiptHtml(
  ReceiptDetail detail,
  String? overrideParchiNo,
  String? marketName,
  String? ownerName,
) {
  final receipt = detail.receipt;
  final items = detail.consolidatedItems;
  final pages = _receiptItemPages(items);
  final displayedParchiNo =
      overrideParchiNo ?? canonicalParchiNumber(receipt.receiptNumber);
  final otcMarker = receipt.isOtc ? '<div class="otc-marker">OTC</div>' : '';
  final tickets = List.generate(pages.length, (pageIndex) {
    final pageItems = pages[pageIndex];
    final pageParchiNo = _parchiNoForPage(displayedParchiNo, pageIndex);
    final pageTotal = _localizeDigits(
      _formatAmount(_pageTotalAmount(pageItems, receipt.isOtc)),
    );
    final totalBlock = '''
    $otcMarker
      <div class="grid-rule"></div>
      <div class="total-label">${_escapeHtml(AppLocalizations.trCurrent('TOTAL'))}</div>
      <div class="total-value">${_escapeHtml(pageTotal)}</div>
      <div class="grid-rule final-rule"></div>
''';
    return '''
  <div class="ticket">
      <div class="top-row">
        <div class="top-left">
          <div class="top-label"><span class="parchi-label">${_escapeHtml(AppLocalizations.trCurrent('PARCHI NO. '))}</span><span class="parchi-number">${_escapeHtml(_localizeDigits(pageParchiNo))}</span></div>
          <div class="session-label">${_escapeHtml(_translatedSession(receipt.session).toUpperCase())}</div>
        </div>
        <div class="datetime">
          <div>${_escapeHtml(_localizeDigits(_formattedDate(receipt)))}</div>
          <div>${_escapeHtml(_localizeDigits(_formattedTime(receipt)))}</div>
        </div>
      </div>
      ${_ownerBlock(ownerName)}
      <div class="market">${_escapeHtml(_marketTitle(receipt, marketName))} - ${_escapeHtml(_translatedSession(receipt.session))}</div>
    <div class="rule"></div>
    <div class="entries-grid">
      <div class="header-cell">${_escapeHtml(AppLocalizations.trCurrent('NUMBER'))}</div>
      <div class="header-cell amount-cell">${_escapeHtml(AppLocalizations.trCurrent('AMT'))}</div>
      ${_receiptRows(pageItems, receipt.session)}
      $totalBlock
    </div>
      <div class="receipt-instruction">${_escapeHtml(AppLocalizations.trCurrent('Please check the receipt. No complaints will be accepted later.'))}</div>
  </div>
''';
  }).join();

  return '''
<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <title>Parchi ${canonicalParchiNumber(receipt.receiptNumber)}</title>
  <style>
    @page { margin: 0; size: 58mm auto; }
    body {
      width: 58mm;
      margin: 0;
      padding: 0;
      font-family: "Noto Sans Devanagari", Arial, Helvetica, sans-serif;
    }

    .ticket {
      width: 58mm;
      min-height: 100%;
      box-sizing: border-box;
      padding: 12px 10px;
      background: #ffffff;
      break-after: page;
      page-break-after: always;
    }

    .ticket:last-child {
      break-after: auto;
      page-break-after: auto;
    }

    .top-row {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
    }

    .top-label {
      color: #111820;
      line-height: 1.2;
      letter-spacing: 0;
    }

    .parchi-label {
      font-size: 10px;
      font-weight: 800;
    }

    .parchi-number {
      font-size: 11px;
      font-weight: 900;
    }

    .session-label {
      margin-top: 2px;
      color: #111820;
      font-size: 9px;
      font-weight: 900;
      line-height: 1;
      letter-spacing: 0;
    }

    .market {
      margin: 12px 0 8px;
      text-align: center;
      font-size: 16px;
      font-weight: 900;
      line-height: 1.1;
      letter-spacing: 0;
    }

    .owner-name {
      margin-top: 12px;
      text-align: center;
      font-size: 11px;
      font-weight: 900;
      line-height: 1;
      letter-spacing: 0;
    }

    .datetime {
      color: #111820;
      text-align: right;
      font-size: 10px;
      font-weight: 800;
      line-height: 1.2;
      letter-spacing: 0;
    }

    .datetime > div + div {
      margin-top: 4px;
    }

    .rule {
      border-top: 2px solid #111820;
      height: 0;
    }

    .entries-grid {
      display: grid;
      grid-template-columns: max-content max-content;
      column-gap: 12px;
      row-gap: 6px;
      align-items: baseline;
      width: max-content;
      max-width: 100%;
      margin-top: 8px;
      margin-left: auto;
      margin-right: auto;
    }

    .header-cell {
      font-size: 10px;
      font-weight: 900;
      letter-spacing: 0;
      line-height: 1.1;
      margin-bottom: 0;
    }

    .amount-cell {
      text-align: right;
    }

    .num {
      font-size: 11px;
      font-weight: 900;
      letter-spacing: 0;
      color: #111820;
      text-align: left;
      min-width: 0;
      width: max-content;
      max-width: none;
      line-height: 1;
      white-space: nowrap;
      overflow: visible;
    }

    .num-main {
      font-weight: 800;
      color: #111820;
    }

    .num-suffix {
      font-size: 11px;
      font-weight: 900;
      color: #000000;
      text-shadow: 0.18px 0 #000000;
    }

    .amt {
      font-size: 11px;
      font-weight: 900;
      letter-spacing: 0;
      min-width: max-content;
      text-align: right;
      line-height: 1;
    }

    .jackpot-num {
      font-size: 10px;
      font-weight: 900;
      letter-spacing: 0;
      min-width: 0;
      max-width: 25mm;
      text-align: left;
      line-height: 1;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }

    .jackpot-amt {
      min-width: max-content;
      text-align: right;
      line-height: 1;
      font-size: 10px;
      font-weight: 900;
    }

    .jackpot-arrow {
      display: inline-block;
      font-size: 13px;
      line-height: 1;
      font-weight: 900;
      letter-spacing: 0;
    }

    .item-label {
      grid-column: 1 / -1;
      margin: 2px 0 -1px;
      font-size: 11px;
      font-weight: 900;
      line-height: 1;
      letter-spacing: 0;
      text-align: left;
      color: #000000;
      text-shadow: 0.18px 0 #000000;
    }

    .grid-rule {
      grid-column: 1 / -1;
      border-top: 2px solid #111820;
      height: 0;
      margin-top: 12px;
    }

    .total-label,
    .total-value {
      margin: 4px 0;
      font-size: 14px;
      font-weight: 900;
      letter-spacing: 0;
      color: #111820;
    }

    .total-value {
      text-align: right;
      min-width: max-content;
    }

    .final-rule {
      margin-top: 0;
    }

    .receipt-instruction {
      width: 50mm;
      max-width: 50mm;
      box-sizing: border-box;
      padding: 0 1mm;
      margin: 2mm auto 0;
      text-align: center;
      font-size: 7px;
      font-weight: 700;
      line-height: 1.1;
      overflow-wrap: anywhere;
    }

    .otc-marker {
      grid-column: 1 / -1;
      margin: 12px 0 0;
      text-align: center;
      color: #108438;
      font-size: 12px;
      font-weight: 900;
      letter-spacing: 0;
    }

    @media print {
      @page { margin: 0; size: 58mm auto; }
      html, body { width: 58mm; margin: 0; padding: 0; }
      .ticket {
        box-shadow: none;
      }
    }
    
    @media screen {
      body {
        background: #f3f4f6;
        padding: 12px;
      }

      .ticket {
        margin: 0 auto 12px;
        box-shadow: 0 8px 24px rgba(15, 23, 42, 0.18);
      }
    }
  </style>
</head>
<body>
$tickets
</body>
</html>
''';
}

class _ParchiPrintItem {
  const _ParchiPrintItem({
    required this.item,
    required this.jackpotEntries,
    this.showMainEntry = true,
  });

  final ReceiptItemModel item;
  final List<JackpotEntryModel> jackpotEntries;
  final bool showMainEntry;
}

List<List<_ParchiPrintItem>> _receiptItemPages(List<ReceiptItemModel> items) {
  if (items.isEmpty) return [const <_ParchiPrintItem>[]];
  final pages = <List<_ParchiPrintItem>>[];
  var currentPage = <_ParchiPrintItem>[];
  var currentEntryCount = 0;

  void pushCurrentPage() {
    if (currentPage.isEmpty) return;
    pages.add(currentPage);
    currentPage = <_ParchiPrintItem>[];
    currentEntryCount = 0;
  }

  void ensurePageSpace() {
    if (currentEntryCount >= _parchiEntriesPerPage) pushCurrentPage();
  }

  for (final item in items) {
    final jackpotEntries = _visibleJackpotEntries(item);
    ensurePageSpace();

    final jackpotSpaceOnMainPage =
        _parchiEntriesPerPage - currentEntryCount - 1;
    final mainJackpotCount = jackpotEntries.length < jackpotSpaceOnMainPage
        ? jackpotEntries.length
        : jackpotSpaceOnMainPage;
    currentPage.add(_ParchiPrintItem(
      item: item,
      jackpotEntries: jackpotEntries.sublist(0, mainJackpotCount),
    ));
    currentEntryCount += 1 + mainJackpotCount;

    var jackpotIndex = mainJackpotCount;
    while (jackpotIndex < jackpotEntries.length) {
      ensurePageSpace();
      final available = _parchiEntriesPerPage - currentEntryCount;
      final nextIndex = jackpotIndex + available > jackpotEntries.length
          ? jackpotEntries.length
          : jackpotIndex + available;
      currentPage.add(_ParchiPrintItem(
        item: item,
        jackpotEntries: jackpotEntries.sublist(jackpotIndex, nextIndex),
        showMainEntry: false,
      ));
      currentEntryCount += nextIndex - jackpotIndex;
      jackpotIndex = nextIndex;
    }
  }
  pushCurrentPage();
  return pages;
}

List<JackpotEntryModel> _visibleJackpotEntries(ReceiptItemModel item) {
  if (!item.isJackpot) return const <JackpotEntryModel>[];
  return item.jackpotEntries
      .where((entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty)
      .toList(growable: false);
}

String _parchiNoForPage(String parchiNo, int pageIndex) {
  if (pageIndex <= 0) return parchiNo;
  final match = RegExp(r'^(.*?)(\d+)$').firstMatch(parchiNo.trim());
  if (match == null) return '$parchiNo-${pageIndex + 1}';
  final prefix = match.group(1) ?? '';
  final numberText = match.group(2) ?? '';
  final number = int.tryParse(numberText);
  if (number == null) return '$parchiNo-${pageIndex + 1}';
  return '$prefix${(number + pageIndex).toString().padLeft(numberText.length, '0')}';
}

num _pageTotalAmount(List<_ParchiPrintItem> items, bool isOtc) {
  final baseTotal = items.fold<num>(
    0,
    (total, pageItem) =>
        total + (pageItem.showMainEntry ? pageItem.item.amount : 0),
  );
  return isOtc ? baseTotal * 2 : baseTotal;
}

String _receiptRows(List<_ParchiPrintItem> items, String session) {
  return items.map((pageItem) {
    final item = pageItem.item;
    final formattedNumber = _localizeDigits(
      _normalizePrintedFamilyNumber(
        formatParchiNumber(item, item.sessionOverride ?? session),
      ),
    );
    final jackpotRows = pageItem.jackpotEntries.map((entry) {
      final jackpotArrow = _jackpotArrowFor(formattedNumber, entry.number);
      return '''
      <div class="jackpot-num"><span class="jackpot-arrow">${_escapeHtml(jackpotArrow)}</span>${_escapeHtml(_localizeDigits(entry.number))} &gt;</div>
      <div class="jackpot-amt">${_escapeHtml(_localizeDigits(entry.amount))}</div>
    ''';
    }).join();
    final topLabel = !pageItem.showMainEntry
        ? ''
        : item.isBazarSangam
            ? '<div class="item-label">BAZAR</div>'
            : item.isMotorPana
                ? '<div class="item-label">MP</div>'
                : '';
    final mainRow = pageItem.showMainEntry
        ? '''
      <div class="num">${_numberHtml(formattedNumber)}</div>
      <div class="amt">${_escapeHtml(_localizeDigits(item.effectiveDisplayAmount))}</div>
'''
        : '';

    return '''
      $topLabel
      $mainRow
      $jackpotRows
    ''';
  }).join();
}

String _numberHtml(String rawText) {
  final parts = NumberDisplayParts.fromDisplay(rawText);
  final leading = parts.leadingArrow.isEmpty
      ? ''
      : '<span class="num-suffix">${_escapeHtml(parts.leadingArrow)} </span>';
  final suffix = parts.suffix.isEmpty
      ? ''
      : ' <span class="num-suffix">${_escapeHtml(parts.suffix)}</span>';
  final trailing = parts.trailingArrow.isEmpty
      ? ''
      : ' <span class="num-suffix">${_escapeHtml(parts.trailingArrow)}</span>';
  return '$leading<span class="num-main">${_escapeHtml(parts.beforeSuffix)}</span>$suffix$trailing';
}

String _normalizePrintedFamilyNumber(String value) {
  final match = RegExp(
    r'^(.*?)(?:\s*[fF]|[fF]\s*)([0-9]{2,3})(\s*>?)$',
  ).firstMatch(value.trim());
  if (match == null) return value;
  final prefix = match.group(1)?.trim() ?? '';
  final number = match.group(2) ?? '';
  final arrow = match.group(3)?.trim() ?? '';
  return '$prefix${number}F$arrow';
}

String _jackpotArrowFor(String parentNumber, String jackpotNumber) {
  final markerIndex = parentNumber.lastIndexOf('>');
  if (markerIndex == -1) return '->';
  final parentPrefixLength = parentNumber.substring(0, markerIndex).length;
  final dashCount = parentPrefixLength - jackpotNumber.trim().length - 2;
  final line = '─' * (dashCount < 1 ? 1 : dashCount);
  return '$line>';
}

String _marketTitle(ReceiptSummary receipt, [String? marketName]) {
  final suppliedName = marketName?.trim();
  if (suppliedName != null && suppliedName.isNotEmpty) {
    return AppLocalizations.localizeMarketName(suppliedName.toUpperCase());
  }
  final name = receipt.market?.name.trim();
  return AppLocalizations.localizeMarketName(
    (name == null || name.isEmpty ? '-' : name).toUpperCase(),
  );
}

String _ownerBlock(String? ownerName) {
  final value = ownerName?.trim() ?? '';
  if (value.isEmpty) return '';
  return '<div class="owner-name">${_escapeHtml(value.toUpperCase())}</div>';
}

String _sessionLabel(String session) {
  final value = session.trim();
  return value.isEmpty ? '-' : value.toUpperCase();
}

String _translatedSession(String session) {
  return AppLocalizations.trCurrent(_sessionLabel(session));
}

String _localizeDigits(String value) {
  return AppLocalizations.localizeDigits(value);
}

String _formattedDate(ReceiptSummary receipt) {
  final date = receipt.createdAt ?? DateTime.now();
  return DateFormat('dd/MM/yyyy').format(date);
}

String _formattedTime(ReceiptSummary receipt) {
  final date = receipt.createdAt ?? DateTime.now();
  return DateFormat('hh:mm a').format(date);
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}

String _formatAmount(num amount) {
  final text = amount.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}
