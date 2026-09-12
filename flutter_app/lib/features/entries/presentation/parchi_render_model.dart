import 'package:intl/intl.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

const int parchiEntriesPerPage = 10;

class ParchiRenderModel {
  const ParchiRenderModel({
    required this.receiptNumber,
    required this.marketName,
    required this.session,
    required this.date,
    required this.pages,
  });

  final String receiptNumber;
  final String marketName;
  final String session;
  final DateTime date;
  final List<ParchiRenderPage> pages;
}

class ParchiRenderPage {
  const ParchiRenderPage({
    required this.parchiNo,
    required this.totalAmount,
    required this.isOtc,
    required this.lines,
  });

  final String parchiNo;
  final num totalAmount;
  final bool isOtc;
  final List<ParchiRenderLine> lines;
}

class ParchiRenderLine {
  const ParchiRenderLine({
    required this.number,
    required this.amount,
    this.topLabel,
    this.showMainEntry = true,
    this.jackpotEntries = const [],
  });

  final String number;
  final String amount;
  final String? topLabel;
  final bool showMainEntry;
  final List<ParchiRenderJackpotEntry> jackpotEntries;
}

class ParchiRenderJackpotEntry {
  const ParchiRenderJackpotEntry({
    required this.arrow,
    required this.number,
    required this.amount,
  });

  final String arrow;
  final String number;
  final String amount;
}

ParchiRenderModel buildParchiRenderModel(
  ReceiptDetail detail, {
  String? overrideParchiNo,
}) {
  final receipt = detail.receipt;
  final sourceItems = detail.consolidatedItems;
  final itemPages = _receiptItemPages(sourceItems);
  final pageTotals = computeParchiPageTotals(
    sourceItems,
    isOtc: receipt.isOtc,
  );
  final baseParchiNo = (overrideParchiNo?.trim().isNotEmpty ?? false)
      ? overrideParchiNo!.trim()
      : receipt.receiptNumber.trim();

  final pages = <ParchiRenderPage>[];
  for (var pageIndex = 0; pageIndex < itemPages.length; pageIndex++) {
    final pageItems = itemPages[pageIndex];
    pages.add(
      ParchiRenderPage(
        parchiNo: _parchiNoForPage(baseParchiNo, pageIndex),
        totalAmount: pageTotals[pageIndex],
        isOtc: receipt.isOtc,
        lines: [
          for (var index = 0; index < pageItems.length; index++)
            () {
              final pageItem = pageItems[index];
              final showMotorLabel = pageItem.item.isMotorPana &&
                  (index == 0 || !pageItems[index - 1].item.isMotorPana);
              return ParchiRenderLine(
                number: formatParchiItemNumber(
                  pageItem.item,
                  pageItem.item.sessionOverride ?? receipt.session,
                ),
                amount: pageItem.item.effectiveDisplayAmount,
                topLabel: !pageItem.showMainEntry
                    ? null
                    : pageItem.item.isBazarSangam
                        ? 'BAZAR'
                        : showMotorLabel
                            ? 'MP'
                            : null,
                showMainEntry: pageItem.showMainEntry,
                jackpotEntries: [
                  for (final entry in pageItem.jackpotEntries)
                    ParchiRenderJackpotEntry(
                      arrow: jackpotArrowFor(
                        formatParchiItemNumber(
                          pageItem.item,
                          pageItem.item.sessionOverride ?? receipt.session,
                        ),
                        entry.number,
                      ),
                      number: entry.number,
                      amount: entry.amount,
                    ),
                ],
              );
            }(),
        ],
      ),
    );
  }

  return ParchiRenderModel(
    receiptNumber: baseParchiNo,
    marketName: _marketTitle(receipt),
    session: _sessionLabel(receipt.session),
    date: receipt.createdAt ?? receipt.date ?? DateTime.now(),
    pages: pages.isEmpty
        ? [
            ParchiRenderPage(
              parchiNo: baseParchiNo,
              totalAmount: pageTotals.first,
              isOtc: receipt.isOtc,
              lines: const [],
            ),
          ]
        : pages,
  );
}

List<num> computeParchiPageTotals(
  List<ReceiptItemModel> items, {
  required bool isOtc,
}) {
  if (items.isEmpty) return const [0];

  final totals = <num>[];
  var currentPageTotal = 0.0;
  var currentEntryCount = 0;

  void pushCurrentPage() {
    totals.add(currentPageTotal * (isOtc ? 2 : 1));
    currentPageTotal = 0;
    currentEntryCount = 0;
  }

  for (final item in items) {
    final jackpotEntries = _visibleJackpotEntries(item);
    final requiredEntryCount = 1 + jackpotEntries.length;
    if (currentEntryCount > 0 &&
        currentEntryCount + requiredEntryCount > parchiEntriesPerPage) {
      pushCurrentPage();
    }

    final availableOnMain = parchiEntriesPerPage - currentEntryCount - 1;
    final mainJackpotCount = jackpotEntries.length < availableOnMain
        ? jackpotEntries.length
        : availableOnMain;
    final jackpotTotal = jackpotEntries.fold<double>(
      0,
      (total, entry) => total + _parseReceiptAmount(entry.amount),
    );
    final mainJackpotTotal = jackpotEntries.take(mainJackpotCount).fold<double>(
          0,
          (total, entry) => total + _parseReceiptAmount(entry.amount),
        );
    final mainAmount = item.amount.toDouble() - jackpotTotal + mainJackpotTotal;
    currentPageTotal += mainAmount < 0 ? 0 : mainAmount;
    currentEntryCount += 1 + mainJackpotCount;

    var jackpotIndex = mainJackpotCount;
    while (jackpotIndex < jackpotEntries.length) {
      if (currentEntryCount >= parchiEntriesPerPage) pushCurrentPage();
      final available = parchiEntriesPerPage - currentEntryCount;
      final nextIndex = jackpotIndex + available > jackpotEntries.length
          ? jackpotEntries.length
          : jackpotIndex + available;
      currentPageTotal +=
          jackpotEntries.sublist(jackpotIndex, nextIndex).fold<double>(
                0,
                (total, entry) => total + _parseReceiptAmount(entry.amount),
              );
      currentEntryCount += nextIndex - jackpotIndex;
      jackpotIndex = nextIndex;
    }
  }

  if (currentEntryCount > 0 || totals.isEmpty) pushCurrentPage();
  return totals;
}

double _parseReceiptAmount(String value) {
  return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
}

String formatParchiAmount(num amount) {
  final text = amount.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'\.?0+$'), '');
}

String formatParchiDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

String formatParchiTime(DateTime date) => DateFormat('hh:mm a').format(date);

String formatParchiItemNumber(ReceiptItemModel item, String session) {
  var formattedNumber =
      item.displayNumber.replaceAll('*', ' * ').replaceAll('-', ' * ');
  final normalizedSession = session.trim().toLowerCase();

  if (item.isCpJodi) {
    final cpNumber = formattedNumber
        .replaceFirst(RegExp(r'^[cC][pP]\s*'), '')
        .replaceFirst(RegExp(r'\s*[cC][pP]$'), '')
        .trim();
    if (normalizedSession == 'open') return '$cpNumber CP >';
    if (normalizedSession == 'close') return '>$cpNumber CP';
    return '$cpNumber CP';
  }

  final cutPNumber = formattedNumber
      .replaceFirst(RegExp(r'\s*CUT\s+P$', caseSensitive: false), '')
      .trim();
  if (cutPNumber != formattedNumber.trim()) {
    formattedNumber = '$cutPNumber CUT P';
  }

  if (item.isSimpleJodi) return formattedNumber.trim();

  if (item.isFamily) {
    formattedNumber = formattedNumber
        .replaceFirst(RegExp(r'^[fF]\s*'), '')
        .replaceFirst(RegExp(r'\s*[fF]$'), '')
        .trim();
    formattedNumber = '${formattedNumber}F';
  }
  final isJodiFamily = item.isFamily &&
      RegExp(r'^\d{2}\s*F$', caseSensitive: false)
          .hasMatch(formattedNumber.trim());

  if (normalizedSession == 'open') {
    if (item.isCommon &&
        !formattedNumber.trim().toUpperCase().endsWith('COMMON')) {
      formattedNumber = '$formattedNumber COMMON';
    }
    return isJodiFamily ? formattedNumber : '$formattedNumber >';
  }

  if (normalizedSession == 'close') {
    if (item.isCommon &&
        !formattedNumber.trim().toUpperCase().endsWith('COMMON')) {
      formattedNumber = '$formattedNumber COMMON';
    }
    return isJodiFamily ? formattedNumber : '> $formattedNumber';
  }

  if (item.isCommon &&
      !formattedNumber.trim().toUpperCase().endsWith('COMMON')) {
    return '$formattedNumber COMMON';
  }
  return formattedNumber.trim();
}

String jackpotArrowFor(String parentNumber, String jackpotNumber) {
  final markerIndex = parentNumber.lastIndexOf('>');
  if (markerIndex == -1) return '\u2500>';
  final parentPrefixLength = parentNumber.substring(0, markerIndex).length;
  final count = parentPrefixLength - jackpotNumber.trim().length - 2;
  return '${'\u2500' * (count < 1 ? 1 : count)}>';
}

class _ParchiPageItem {
  const _ParchiPageItem({
    required this.item,
    required this.jackpotEntries,
    this.showMainEntry = true,
  });

  final ReceiptItemModel item;
  final List<JackpotEntryModel> jackpotEntries;
  final bool showMainEntry;
}

List<List<_ParchiPageItem>> _receiptItemPages(List<ReceiptItemModel> items) {
  if (items.isEmpty) return [const <_ParchiPageItem>[]];
  final pages = <List<_ParchiPageItem>>[];
  var currentPage = <_ParchiPageItem>[];
  var currentEntryCount = 0;

  void pushCurrentPage() {
    if (currentPage.isEmpty) return;
    pages.add(currentPage);
    currentPage = <_ParchiPageItem>[];
    currentEntryCount = 0;
  }

  void ensurePageSpace() {
    if (currentEntryCount >= parchiEntriesPerPage) pushCurrentPage();
  }

  for (final item in items) {
    final jackpotEntries = _visibleJackpotEntries(item);
    ensurePageSpace();

    final jackpotSpaceOnMainPage = parchiEntriesPerPage - currentEntryCount - 1;
    final mainJackpotCount = jackpotEntries.length < jackpotSpaceOnMainPage
        ? jackpotEntries.length
        : jackpotSpaceOnMainPage;
    currentPage.add(
      _ParchiPageItem(
        item: item,
        jackpotEntries: jackpotEntries.sublist(0, mainJackpotCount),
      ),
    );
    currentEntryCount += 1 + mainJackpotCount;

    var jackpotIndex = mainJackpotCount;
    while (jackpotIndex < jackpotEntries.length) {
      ensurePageSpace();
      final available = parchiEntriesPerPage - currentEntryCount;
      final nextIndex = jackpotIndex + available > jackpotEntries.length
          ? jackpotEntries.length
          : jackpotIndex + available;
      currentPage.add(
        _ParchiPageItem(
          item: item,
          jackpotEntries: jackpotEntries.sublist(jackpotIndex, nextIndex),
          showMainEntry: false,
        ),
      );
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

String _marketTitle(ReceiptSummary receipt) {
  final name = receipt.market?.name.trim();
  return (name == null || name.isEmpty ? '-' : name).toUpperCase();
}

String _sessionLabel(String session) {
  final value = session.trim();
  return value.isEmpty ? '-' : value.toUpperCase();
}
