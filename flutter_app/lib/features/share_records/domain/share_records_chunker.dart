import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/share_records/data/share_records_models.dart';

class ShareRecordsChunker {
  ShareRecordsChunker._();

  static const int maxVisualLinesPerBox = 10;
  static const int maxEntriesPerBox = maxVisualLinesPerBox;
  static const int maxBoxesPerPage = 10;

  static List<RecordBoxData> buildBoxes(List<ShareRecordEntry> records) {
    final boxes = <RecordBoxData>[];
    int currentSequence = 1;

    for (final record in records) {
      final items = record.items;
      if (items.isEmpty) continue;

      final chunks = _parchiItemChunks(items);
      final totalParts = chunks.length;

      for (int p = 0; p < chunks.length; p++) {
        final chunkItems = chunks[p];
        final chunkSubtotal = chunkItems.fold<num>(
          0,
          (sum, item) => sum + item.amount,
        );
        boxes.add(
          RecordBoxData(
            sequenceNumber: currentSequence++,
            receiptId: record.receiptId,
            receiptNumber: record.receiptNumber,
            customerName: record.customerName,
            marketName: record.market.name,
            session: record.session,
            isOtc: record.isOtc,
            createdAt: record.createdAt,
            date: record.date,
            totalReceiptAmount: record.totalAmount,
            partIndex: p + 1,
            totalParts: totalParts,
            boxSubtotal: chunkSubtotal,
            items: chunkItems,
          ),
        );
      }
    }

    return boxes;
  }

  static List<List<ShareRecordItem>> _parchiItemChunks(
    List<ShareRecordItem> items,
  ) {
    final chunks = <List<ShareRecordItem>>[];
    var current = <ShareRecordItem>[];
    var currentLineCount = 0;

    void pushCurrent() {
      if (current.isEmpty) return;
      chunks.add(current);
      current = <ShareRecordItem>[];
      currentLineCount = 0;
    }

    void ensureSpace(int neededLines) {
      if (current.isNotEmpty &&
          currentLineCount + neededLines > maxVisualLinesPerBox) {
        pushCurrent();
      }
    }

    for (final item in items) {
      final jackpotEntries = _visibleJackpotEntries(item);
      final mainLineCount = _mainVisualLineCount(item);
      final requiredLineCount = mainLineCount + jackpotEntries.length;
      ensureSpace(requiredLineCount);

      final fullJackpotTotal = _jackpotAmountTotal(jackpotEntries);
      var mainAmount = item.amount - fullJackpotTotal;
      if (mainAmount < 0) mainAmount = 0;

      final jackpotSpaceOnMainBox =
          maxVisualLinesPerBox - currentLineCount - mainLineCount;
      final mainJackpotCount = jackpotEntries.length < jackpotSpaceOnMainBox
          ? jackpotEntries.length
          : jackpotSpaceOnMainBox;
      final mainJackpotEntries = jackpotEntries.sublist(0, mainJackpotCount);
      final mainVisibleAmount =
          mainAmount + _jackpotAmountTotal(mainJackpotEntries);

      current.add(
        item.copyForParchi(
          showMainEntry: true,
          jackpotEntries: mainJackpotEntries,
          amount: mainVisibleAmount,
          displayAmount: item.displayAmount,
        ),
      );
      currentLineCount += mainLineCount + mainJackpotCount;

      var jackpotIndex = mainJackpotCount;
      while (jackpotIndex < jackpotEntries.length) {
        if (currentLineCount >= maxVisualLinesPerBox) pushCurrent();
        final available = maxVisualLinesPerBox - currentLineCount;
        final nextIndex = jackpotIndex + available > jackpotEntries.length
            ? jackpotEntries.length
            : jackpotIndex + available;
        final continuationEntries = jackpotEntries.sublist(
          jackpotIndex,
          nextIndex,
        );
        final continuationAmount = _jackpotAmountTotal(continuationEntries);
        current.add(
          item.copyForParchi(
            showMainEntry: false,
            jackpotEntries: continuationEntries,
            amount: continuationAmount,
            displayAmount: _formatAmount(continuationAmount),
          ),
        );
        currentLineCount += nextIndex - jackpotIndex;
        jackpotIndex = nextIndex;
      }
    }

    pushCurrent();
    return chunks;
  }

  static List<ShareRecordJackpotEntry> _visibleJackpotEntries(
    ShareRecordItem item,
  ) {
    if (!item.isJackpot) return const <ShareRecordJackpotEntry>[];
    return item.jackpotEntries
        .where((entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty)
        .toList(growable: false);
  }

  static int _mainVisualLineCount(ShareRecordItem item) {
    return 1;
  }

  static num _jackpotAmountTotal(List<ShareRecordJackpotEntry> entries) {
    return entries.fold<num>(
      0,
      (sum, entry) => sum + (num.tryParse(entry.totalAmount.trim()) ?? 0),
    );
  }

  static String _formatAmount(num amount) {
    final text = amount.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static List<A4RecordPageData> buildPages({
    required List<ShareRecordEntry> records,
    required DateTime filterDate,
    required String marketName,
    required String sessionName,
    String? fallbackOperator,
  }) {
    final boxes = buildBoxes(records);
    if (boxes.isEmpty) return const [];

    final totalPages = (boxes.length / maxBoxesPerPage).ceil();
    final locale = AppLanguageStore.current.code;
    final dateStr =
        '${DateFormat('dd-MM-yyyy', locale).format(filterDate)} (${DateFormat('EEEE', locale).format(filterDate)})';
    final timeStr = DateFormat('hh:mm a').format(DateTime.now());

    final totalPeople = records.length;
    final totalBets = records.fold<int>(0, (sum, r) => sum + r.items.length);
    final totalAmount = records.fold<num>(0, (sum, r) => sum + r.totalAmount);

    final operatorName =
        (records.isNotEmpty && records.first.operator.name.isNotEmpty)
            ? records.first.operator.name
            : (fallbackOperator ?? AppLocalizations.trCurrent('OPERATOR 01'));

    final pages = <A4RecordPageData>[];

    for (int p = 0; p < totalPages; p++) {
      final start = p * maxBoxesPerPage;
      final end = (start + maxBoxesPerPage < boxes.length)
          ? start + maxBoxesPerPage
          : boxes.length;
      final pageBoxes = boxes.sublist(start, end);

      pages.add(
        A4RecordPageData(
          pageIndex: p,
          totalPages: totalPages,
          dateStr: dateStr,
          marketName: marketName.isEmpty
              ? AppLocalizations.trCurrent('ALL MARKETS')
              : marketName.toUpperCase(),
          sessionName: sessionName.isEmpty || sessionName == 'All'
              ? AppLocalizations.trCurrent('ALL')
              : AppLocalizations.trCurrent(sessionName.toUpperCase()),
          totalPeople: totalPeople,
          totalBets: totalBets,
          totalAmount: totalAmount,
          operatorName: operatorName.toUpperCase(),
          timeStr: timeStr,
          boxes: pageBoxes,
        ),
      );
    }

    return pages;
  }
}
