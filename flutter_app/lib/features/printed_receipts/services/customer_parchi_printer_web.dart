import 'dart:async';
import 'dart:js_interop';

import 'package:intl/intl.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:web/web.dart' as web;

const _parchiEntriesPerPage = 10;

class CustomerParchiPrintSession {
  const CustomerParchiPrintSession._(this._window);

  final web.Window? _window;

  Future<void> printReceipt(ReceiptDetail detail,
      {String? overrideParchiNo}) async {
    final target =
        _window ?? web.window.open('', '_blank', 'width=420,height=720');
    if (target == null) {
      throw StateError('Print popup was blocked');
    }

    final document = target.document;
    document.open();
    document.write(_buildReceiptHtml(detail, overrideParchiNo).toJS);
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

String _buildReceiptHtml(ReceiptDetail detail, String? overrideParchiNo) {
  final receipt = detail.receipt;
  final items = detail.consolidatedItems;
  final pages = _receiptItemPages(items);
  final displayedParchiNo =
      overrideParchiNo ?? canonicalParchiNumber(receipt.receiptNumber);
  final sessionLabel = _sessionLabel(receipt.session);
  final otcMarker = receipt.isOtc ? '<div class="otc-marker">OTC</div>' : '';
  final tickets = List.generate(pages.length, (pageIndex) {
    final pageItems = pages[pageIndex];
    final pageParchiNo = _parchiNoForPage(displayedParchiNo, pageIndex);
    final pageTotal = _formatAmount(_pageTotalAmount(pageItems, receipt.isOtc));
    final totalBlock = '''
    $otcMarker
    <div class="rule bottom"></div>
    <div class="total-row">
      <span>TOTAL</span>
      <span class="total-value">${_escapeHtml(pageTotal)}</span>
    </div>
    <div class="rule bottom"></div>
''';
    return '''
  <div class="ticket">
      <div class="top-row">
        <div class="top-left">
          <div class="top-label">PARCHI NO. ${_escapeHtml(pageParchiNo)}</div>
          <div class="session-label">${_escapeHtml(sessionLabel)}</div>
        </div>
        <div class="datetime">
          <div>${_escapeHtml(_formattedDate(receipt))}</div>
          <div>${_escapeHtml(_formattedTime(receipt))}</div>
        </div>
      </div>
      <div class="market">${_escapeHtml(_marketTitle(receipt))}</div>
      <div class="rule"></div>
      <div class="header">
        <div>NUMBER</div>
        <div>AMT</div>
      </div>
      ${_receiptRows(pageItems, receipt.session)}
      $totalBlock
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
      font-family: Arial, Helvetica, sans-serif;
    }

    .ticket {
      width: 58mm;
      min-height: 100%;
      padding: 6mm 4mm 5mm;
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
      font-size: 9px;
      font-weight: 900;
      line-height: 1.05;
      letter-spacing: 0;
    }

    .session-label {
      margin-top: 1mm;
      font-size: 10px;
      font-weight: 900;
      line-height: 1;
      letter-spacing: 0;
    }

    .market {
      margin: 7mm 0 1mm;
      text-align: center;
      font-size: 15px;
      font-weight: 900;
      line-height: 1.05;
      letter-spacing: 0;
    }

    .datetime {
      text-align: right;
      font-size: 9px;
      font-weight: 600;
      line-height: 1.05;
      letter-spacing: 0;
    }

    .rule {
      border-top: 1.2px solid #111820;
      height: 0;
    }

    .header {
      display: flex;
      justify-content: space-between;
      margin-top: 2.5mm;
      margin-bottom: 2mm;
      font-size: 8px;
      font-weight: 900;
      letter-spacing: 0;
      line-height: 1.1;
    }

    .row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      margin-bottom: 1.2mm;
      gap: 6px;
      text-align: left;
      min-height: 16px;
    }

    .num {
      font-size: 15px;
      font-weight: 900;
      letter-spacing: 0;
      flex: 1;
      color: #111820;
      text-align: left;
      min-width: 0;
      line-height: 1.2;
    }

    .num-main {
      font-weight: 800;
      color: #111820;
    }

    .num-suffix {
      font-size: 14px;
      font-weight: 900;
      color: #000000;
      text-shadow: 0.18px 0 #000000;
    }

    .amt {
      font-size: 15px;
      font-weight: 900;
      letter-spacing: 0;
      width: 15mm;
      text-align: right;
      margin-left: 6px;
      line-height: 1.2;
    }

    .jackpot-row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      gap: 8px;
      margin: -0.5mm 0 1.5mm;
      font-size: 12px;
      font-weight: 900;
      letter-spacing: 0;
      text-align: left;
    }

    .jackpot-num {
      flex: 1;
      min-width: 0;
      text-align: left;
      line-height: 1.2;
    }

    .jackpot-amt {
      width: 15mm;
      text-align: right;
      line-height: 1.2;
    }

    .jackpot-arrow {
      display: inline-block;
      font-size: 16px;
      line-height: 1;
      font-weight: 900;
      letter-spacing: 0;
    }

    .item-label {
      margin: 0 0 1mm;
      font-size: 14px;
      font-weight: 900;
      line-height: 1;
      letter-spacing: 0;
      text-align: left;
      color: #000000;
      text-shadow: 0.18px 0 #000000;
      width: calc(100% - 15mm);
      margin-right: 15mm;
    }

    .bottom {
      margin-top: 3mm;
    }

    .total-row {
      display: flex;
      justify-content: space-between;
      align-items: baseline;
      margin: 2.5mm 0;
      font-size: 12px;
      font-weight: 900;
      letter-spacing: 0;
      text-shadow: 0.18px 0 #108438;
    }

    .total-value {
      display: inline-flex;
      align-items: baseline;
      gap: 4px;
    }

    .otc-marker {
      margin: 1.5mm 0 0.8mm;
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
    final formattedNumber = formatParchiNumber(item, session);
    final jackpotRows = pageItem.jackpotEntries.map((entry) {
      final jackpotArrow = _jackpotArrowFor(formattedNumber, entry.number);
      return '''
      <div class="jackpot-row">
        <div class="jackpot-num">
          <span class="jackpot-arrow">${_escapeHtml(jackpotArrow)}</span>${_escapeHtml(entry.number)} &gt;
        </div>
        <div class="jackpot-amt">${_escapeHtml(entry.amount)}</div>
      </div>
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
      <div class="row">
        <div class="num">${_numberHtml(formattedNumber)}</div>
        <div class="amt">${_escapeHtml(item.effectiveDisplayAmount)}</div>
      </div>
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

String _jackpotArrowFor(String parentNumber, String jackpotNumber) {
  final markerIndex = parentNumber.lastIndexOf('>');
  if (markerIndex == -1) return '->';
  final parentPrefixLength = parentNumber.substring(0, markerIndex).length;
  final dashCount = parentPrefixLength - jackpotNumber.trim().length - 2;
  final line = '─' * (dashCount < 1 ? 1 : dashCount);
  return '$line>';
}

String _marketTitle(ReceiptSummary receipt) {
  final name = receipt.market?.name.trim();
  return (name == null || name.isEmpty ? '-' : name).toUpperCase();
}

String _sessionLabel(String session) {
  final value = session.trim();
  return value.isEmpty ? '-' : value.toUpperCase();
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
