import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/shared/widgets/aligned_jackpot_marker.dart';

const entryBlue = Color(0xFF064DB5);
const entryGreen = Color(0xFF108438);
const entryRed = Color(0xFFF20D16);
const entryOrange = Color(0xFFF97316);
const entryLine = Color(0xFFD8DCE3);
const rupee = '\u20B9';
const _parchiEntriesPerPage = 10;
const _receiptAlphabetShadow = <Shadow>[
  Shadow(color: Colors.black, offset: Offset(0.18, 0), blurRadius: 0),
];
const _receiptGreenAlphabetShadow = <Shadow>[
  Shadow(color: entryGreen, offset: Offset(0.18, 0), blurRadius: 0),
];
const _receiptIndicFontFallback = <String>[
  'Noto Sans Devanagari',
  'Nirmala UI',
  'Mangal',
];

bool _isIndicReceiptPreviewLanguage(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return code == AppLanguage.hindi.code || code == AppLanguage.marathi.code;
}

List<String>? _receiptFontFallback(bool isIndic) {
  return isIndic ? _receiptIndicFontFallback : null;
}

final _date = DateFormat('dd-MM-yyyy');
final _time = DateFormat('hh:mm a');
final _dateTime = DateFormat('dd-MM-yyyy hh:mm a');

String formatDate(DateTime? value) => value == null ? '-' : _date.format(value);
String formatTime(DateTime? value) => value == null ? '-' : _time.format(value);
String formatDateTime(DateTime? value) =>
    value == null ? '-' : _dateTime.format(value);
String formatParchiDate(DateTime? value) =>
    value == null ? '-' : DateFormat('dd/MM/yyyy').format(value);
String formatParchiTime(DateTime? value) =>
    value == null ? '-' : DateFormat('hh:mm a').format(value);

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
    currentPage.add(_ParchiPageItem(
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
      currentPage.add(_ParchiPageItem(
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

class EntryPageHeader extends StatelessWidget {
  const EntryPageHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: entryBlue, size: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: entryBlue,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(color: Color(0xFF334155))),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class NumberedTitle extends StatelessWidget {
  const NumberedTitle(this.number, this.title, {super.key});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$number. $title',
      style: const TextStyle(
        color: entryBlue,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final color = normalized.contains('cancel') ||
            normalized.contains('close') ||
            normalized.contains('failed')
        ? entryRed
        : normalized.contains('not') ||
                normalized.contains('duplicate') ||
                normalized.contains('pending')
            ? entryOrange
            : entryGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {this.valueWidget, super.key});

  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          const Text(':'),
          const SizedBox(width: 8),
          Expanded(
            child: valueWidget ??
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
          ),
        ],
      ),
    );
  }
}

class ReceiptDetailsPanel extends StatelessWidget {
  const ReceiptDetailsPanel({
    required this.detail,
    this.onCancel,
    this.onViewReprints,
    this.cancelling = false,
    this.showActions = true,
    super.key,
  });

  final ReceiptDetail detail;
  final VoidCallback? onCancel;
  final VoidCallback? onViewReprints;
  final bool cancelling;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final receipt = detail.receipt;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Parchi No.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: receipt.receiptNumber),
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Parchi number copied'),
                          ),
                        );
                      },
                      child: Text(
                        receipt.receiptNumber,
                        style: const TextStyle(
                          color: entryBlue,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(receipt.status),
            ],
          ),
          const Divider(height: 22),
          DetailRow(
            'Market',
            AppLocalizations.localizeMarketName(receipt.market?.name ?? '-'),
          ),
          DetailRow('Session', context.tr(receipt.session.toUpperCase())),
          DetailRow('Date & Time', formatDateTime(receipt.date)),
          DetailRow('Entry Mode', context.tr(_entryMode(detail))),
          DetailRow('Operator', receipt.operator?.name ?? '-'),
          if (receipt.customerName != null)
            DetailRow('Customer', receipt.customerName!),
          if (receipt.customerMobile != null)
            DetailRow('Mobile', receipt.customerMobile!),
          DetailRow('Items', '${receipt.totalItems}'),
          DetailRow(
            'Total Amount',
            '$rupee ${receipt.totalAmountText}${receipt.isOtc ? ' OTC' : ''}',
          ),
          DetailRow('Print Status', '',
              valueWidget: StatusBadge(receipt.printStatus)),
          DetailRow('Print Count', '${detail.printCount}'),
          DetailRow(
            'Reprints',
            '',
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${detail.reprintCount}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (detail.reprintCount > 0 && onViewReprints != null) ...[
                  const SizedBox(width: 8),
                  SizedBox.square(
                    dimension: 28,
                    child: IconButton(
                      tooltip: 'View reprint reasons',
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      onPressed: onViewReprints,
                      icon: const Icon(Icons.info_outline, size: 18),
                    ),
                  ),
                ],
              ],
            ),
          ),
          DetailRow(
            'Created At',
            AppLocalizations.localizeDigits(
              formatDateTime(receipt.createdAt ?? receipt.date),
            ),
          ),
          if (receipt.notes != null) DetailRow('Note', receipt.notes!),
          if (receipt.cancelledAt != null)
            DetailRow(
              'Cancelled At',
              AppLocalizations.localizeDigits(
                formatDateTime(receipt.cancelledAt),
              ),
            ),
          if (receipt.cancellationReason != null)
            DetailRow('Cancel Reason', receipt.cancellationReason!),
          if (showActions) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: cancelling ? null : onCancel,
              icon: cancelling
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              label: const Text('Delete Parchi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: entryRed,
                side: const BorderSide(color: entryRed),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ReceiptItemsTable extends StatelessWidget {
  const ReceiptItemsTable(
      {required this.items, this.compact = false, super.key});

  final List<ReceiptItemModel> items;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Column(
        children: [
          for (var index = 0; index < items.length; index++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: _panelDecoration(),
              child: Row(
                children: [
                  Text('${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${context.trMaybe(items[index].displayType)}  ${AppLocalizations.localizeDigits(items[index].displayNumber)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '$rupee ${items[index].effectiveDisplayAmount}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          _itemRow(
            const ['SR.', 'TYPE', 'NUMBER', 'AMOUNT ($rupee)'],
            header: true,
          ),
          for (var index = 0; index < items.length; index++)
            _itemRow([
              AppLocalizations.localizeDigits('${index + 1}'),
              context.trMaybe(items[index].displayType),
              AppLocalizations.localizeDigits(items[index].displayNumber),
              AppLocalizations.localizeDigits(items[index].effectiveDisplayAmount),
            ]),
        ],
      ),
    );
  }

  Widget _itemRow(List<String> values, {bool header = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF6F8FB) : Colors.white,
        border: Border(
            top: BorderSide(color: header ? Colors.transparent : entryLine)),
      ),
      child: Row(
        children: [
          _cell(values[0], 1, header),
          _cell(values[1], 2, header),
          _cell(values[2], 2, header, center: true),
          _cell(values[3], 2, header, right: true),
        ],
      ),
    );
  }

  Widget _cell(String value, int flex, bool header,
      {bool center = false, bool right = false}) {
    return Expanded(
      flex: flex,
      child: Text(
        value,
        textAlign: right
            ? TextAlign.right
            : center
                ? TextAlign.center
                : TextAlign.left,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: header ? FontWeight.w900 : FontWeight.w700,
        ),
      ),
    );
  }
}

class PrintHistoryView extends StatelessWidget {
  const PrintHistoryView({required this.logs, this.compact = false, super.key});

  final List<PrintLogModel> logs;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _panelDecoration(),
        child: const Text('No print history found.'),
      );
    }
    if (compact) {
      return Column(
        children: [
          for (final log in logs)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: _panelDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.printId,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      StatusBadge(log.status),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${context.trMaybe(log.printType)}  #${AppLocalizations.localizeDigits('${log.printNumber ?? '-'}')}  ${formatDateTime(log.printedAt)}',
                  ),
                  Text(
                    context.tr(
                      'Printer: {printer}',
                      params: {'printer': log.printerName},
                    ),
                  ),
                  Text(
                    context.tr(
                      'Created At: {date}',
                      params: {'date': formatDateTime(log.createdAt)},
                    ),
                  ),
                  if (log.reprintReason != null || log.retryReason != null)
                    Text('Reason: ${log.reprintReason ?? log.retryReason}'),
                ],
              ),
            ),
        ],
      );
    }
    return Container(
      decoration: _panelDecoration(),
      child: Column(
        children: [
          _printRow(
            const [
              'SR.',
              'PRINT ID',
              'TYPE',
              'PRINT NO.',
              'PRINT TIME',
              'PRINTER',
              'CREATED AT',
              'REASON',
              'STATUS'
            ],
            header: true,
          ),
          for (var index = 0; index < logs.length; index++)
            _printRow([
              '${index + 1}',
              logs[index].printId,
              context.trMaybe(logs[index].printType),
              AppLocalizations.localizeDigits('${logs[index].printNumber ?? '-'}'),
              formatDateTime(logs[index].printedAt),
              logs[index].printerName,
              AppLocalizations.localizeDigits(
                formatDateTime(logs[index].createdAt),
              ),
              logs[index].reprintReason ?? logs[index].retryReason ?? '-',
              logs[index].status,
            ]),
        ],
      ),
    );
  }

  Widget _printRow(List<String> values, {bool header = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF6F8FB) : Colors.white,
        border: Border(
            top: BorderSide(color: header ? Colors.transparent : entryLine)),
      ),
      child: Row(
        children: [
          _printCell(values[0], 1, header),
          _printCell(values[1], 2, header),
          _printCell(values[2], 2, header),
          _printCell(values[3], 3, header),
          _printCell(values[4], 2, header),
          _printCell(values[5], 2, header),
          _printCell(values[6], 2, header),
          _printCell(values[7], 2, header),
          Expanded(
              flex: 2,
              child: header ? _header(values[8]) : StatusBadge(values[8])),
        ],
      ),
    );
  }

  Widget _printCell(String value, int flex, bool header) {
    return Expanded(
      flex: flex,
      child: header
          ? _header(value)
          : Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _header(String value) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
    );
  }
}

class PrintedReceiptPreview extends StatelessWidget {
  const PrintedReceiptPreview({required this.detail, super.key});

  final ReceiptDetail detail;

  @override
  Widget build(BuildContext context) {
    final receipt = detail.receipt;
    final pages = _receiptItemPages(detail.consolidatedItems);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var pageIndex = 0; pageIndex < pages.length; pageIndex++)
            Padding(
              padding: EdgeInsets.only(
                bottom: pageIndex == pages.length - 1 ? 0 : 18,
              ),
              child: _PrintedReceiptTicket(
                receipt: receipt,
                items: pages[pageIndex],
                showTotal: pageIndex == pages.length - 1,
              ),
            ),
        ],
      ),
    );
  }
}

class _PrintedReceiptTicket extends StatelessWidget {
  const _PrintedReceiptTicket({
    required this.receipt,
    required this.items,
    required this.showTotal,
  });

  final ReceiptSummary receipt;
  final List<_ParchiPageItem> items;
  final bool showTotal;

  @override
  Widget build(BuildContext context) {
    final isIndic = _isIndicReceiptPreviewLanguage(context);
    final columnMetrics = _printedParchiColumnMetrics(
      context,
      items,
      receipt.session,
      receipt.totalAmountText,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: CustomPaint(
        painter: _ReceiptBorderPainter(),
        child: Container(
          color: Colors.white.withValues(alpha: 0.96),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(
                            text: context.tr('PARCHI NO. '),
                            style: TextStyle(
                              fontSize: isIndic ? 11 : 10,
                              fontWeight: isIndic
                                  ? FontWeight.w700
                                  : FontWeight.w800,
                              height: isIndic ? 1.25 : null,
                              fontFamilyFallback:
                                  _receiptFontFallback(isIndic),
                            ),
                          ),
                          TextSpan(
                            text: AppLocalizations.localizeDigits(
                              canonicalParchiNumber(receipt.receiptNumber),
                            ),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isIndic
                                  ? FontWeight.w800
                                  : FontWeight.w900,
                              height: isIndic ? 1.2 : null,
                              fontFamilyFallback:
                                  _receiptFontFallback(isIndic),
                            ),
                          ),
                        ])),
                        const SizedBox(height: 2),
                        Text(
                          context.tr(receipt.session.toUpperCase()),
                          style: TextStyle(
                            fontSize: isIndic ? 10 : 9,
                            fontWeight: isIndic
                                ? FontWeight.w800
                                : FontWeight.w900,
                            height: isIndic ? 1.2 : 1,
                            fontFamilyFallback: _receiptFontFallback(isIndic),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          AppLocalizations.localizeDigits(formatParchiDate(
                              receipt.createdAt ?? receipt.date)),
                          style: TextStyle(
                            fontSize: isIndic ? 11 : 10,
                            fontWeight: isIndic
                                ? FontWeight.w700
                                : FontWeight.w800,
                            height: isIndic ? 1.25 : null,
                            fontFamilyFallback: _receiptFontFallback(isIndic),
                          )),
                      const SizedBox(height: 4),
                      Text(
                          AppLocalizations.localizeDigits(formatParchiTime(
                              receipt.createdAt ?? receipt.date)),
                          style: TextStyle(
                            fontSize: isIndic ? 11 : 10,
                            fontWeight: isIndic
                                ? FontWeight.w700
                                : FontWeight.w800,
                            height: isIndic ? 1.25 : null,
                            fontFamilyFallback: _receiptFontFallback(isIndic),
                          )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${AppLocalizations.localizeMarketName(receipt.market?.name ?? '-')} - ${context.tr(receipt.session.toUpperCase())}',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isIndic ? 15 : 16,
                  fontWeight: isIndic ? FontWeight.w800 : FontWeight.w900,
                  height: isIndic ? 1.25 : null,
                  fontFamilyFallback: _receiptFontFallback(isIndic),
                ),
              ),
              const SizedBox(height: 8),
              const _ParchiRule(),
              const SizedBox(height: 8),
              _ParchiHeader(metrics: columnMetrics),
              for (final pageItem in items)
                _ParchiItemRow(
                  number: formatParchiNumber(
                    pageItem.item,
                    pageItem.item.sessionOverride ?? receipt.session,
                  ),
                  amount: pageItem.item.effectiveDisplayAmount,
                  showMainEntry: pageItem.showMainEntry,
                  isJackpot: pageItem.item.isJackpot,
                  isBazarSangam: pageItem.item.isBazarSangam,
                  isMotorPana: pageItem.item.isMotorPana,
                  jackpotEntries: pageItem.jackpotEntries,
                  metrics: columnMetrics,
                ),
              const SizedBox(height: 12),
              if (showTotal && receipt.isOtc) ...[
                Text(
                  context.tr('OTC'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: entryGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                    shadows: _receiptGreenAlphabetShadow,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const _ParchiRule(),
              if (showTotal) ...[
                const SizedBox(height: 10),
                _ParchiTotalRow(
                  amount: AppLocalizations.localizeDigits(
                    receipt.totalAmountText,
                  ),
                  metrics: columnMetrics,
                ),
                const SizedBox(height: 10),
                const _ParchiRule(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ParchiTotalRow extends StatelessWidget {
  const _ParchiTotalRow({required this.amount, required this.metrics});

  final String amount;
  final _PrintedParchiColumnMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 0, 7, 0),
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: metrics.numberWidth,
              child: Text(
                context.tr('TOTAL'),
                style: const TextStyle(
                  color: Color(0xFF111820),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
            SizedBox(width: metrics.gap),
            SizedBox(
              width: metrics.amountWidth,
              child: Text(
                amount,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF111820),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParchiHeader extends StatelessWidget {
  const _ParchiHeader({required this.metrics});

  final _PrintedParchiColumnMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 0, 7, 6),
      child: Align(
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: metrics.numberWidth,
              child: Text(
                context.tr('NUMBER'),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            SizedBox(width: metrics.gap),
            SizedBox(
              width: metrics.amountWidth,
              child: Text(
                context.tr('AMT'),
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParchiItemRow extends StatelessWidget {
  const _ParchiItemRow({
    required this.number,
    required this.amount,
    this.isJackpot = false,
    this.isBazarSangam = false,
    this.isMotorPana = false,
    this.jackpotEntries = const [],
    this.showMainEntry = true,
    required this.metrics,
  });

  final String number;
  final String amount;
  final bool isJackpot;
  final bool isBazarSangam;
  final bool isMotorPana;
  final List<JackpotEntryModel> jackpotEntries;
  final bool showMainEntry;
  final _PrintedParchiColumnMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final visibleJackpotEntries = isJackpot
        ? jackpotEntries.where(
            (entry) => entry.number.isNotEmpty || entry.amount.isNotEmpty,
          )
        : const Iterable<JackpotEntryModel>.empty();
    final topLabel = !showMainEntry
        ? null
        : isBazarSangam
            ? 'BAZAR'
            : isMotorPana
                ? 'MP'
                : null;
    const baseTextStyle = TextStyle(
      color: Color(0xFF111820),
      fontSize: 11,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 0,
    );
    const suffixTextStyle = TextStyle(
      color: Colors.black,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 0,
      shadows: _receiptAlphabetShadow,
    );
    const jackpotTextStyle = TextStyle(
      color: Color(0xFF111820),
      fontSize: 10,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 0,
    );
    const jackpotArrowStyle = TextStyle(
      color: Color(0xFF111820),
      fontSize: 13,
      fontWeight: FontWeight.w900,
      height: 1,
      letterSpacing: 0,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (topLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: metrics.totalWidth,
                  child: Text(
                    context.tr(topLabel),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      height: 1,
                      letterSpacing: 0,
                      shadows: _receiptAlphabetShadow,
                    ),
                  ),
                ),
              ),
            ),
          if (showMainEntry)
            Align(
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: metrics.numberWidth,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (number.startsWith('>'))
                            const TextSpan(text: '> ', style: suffixTextStyle),
                          TextSpan(
                            text: AppLocalizations.localizeDigits(
                              _displayNumberMain(number),
                            ),
                            style: baseTextStyle,
                          ),
                          if (_displayNumberSuffix(number).isNotEmpty)
                            TextSpan(
                              text: ' ${_displayNumberSuffix(number)}',
                              style: suffixTextStyle,
                            ),
                          if (number.endsWith('>'))
                            const TextSpan(text: ' >', style: suffixTextStyle),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textWidthBasis: TextWidthBasis.longestLine,
                      style: baseTextStyle,
                    ),
                  ),
                  SizedBox(width: metrics.gap),
                  SizedBox(
                    width: metrics.amountWidth,
                    child: Text(
                      AppLocalizations.localizeDigits(amount),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: Color(0xFF111820),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final entry in visibleJackpotEntries)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: metrics.numberWidth,
                      child: AlignedJackpotMarker(
                        parentText: number,
                        childText:
                            '${AppLocalizations.localizeDigits(entry.number)} >',
                        parentStyle: baseTextStyle,
                        arrowStyle: jackpotArrowStyle,
                        childStyle: jackpotTextStyle,
                      ),
                    ),
                    SizedBox(width: metrics.gap),
                    SizedBox(
                      width: metrics.amountWidth,
                      child: Text(
                        AppLocalizations.localizeDigits(entry.amount),
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Color(0xFF111820),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrintedParchiColumnMetrics {
  const _PrintedParchiColumnMetrics({
    required this.numberWidth,
    required this.amountWidth,
    required this.gap,
  });

  final double numberWidth;
  final double amountWidth;
  final double gap;

  double get totalWidth => numberWidth + gap + amountWidth;
}

_PrintedParchiColumnMetrics _printedParchiColumnMetrics(
  BuildContext context,
  List<_ParchiPageItem> items,
  String session,
  String totalAmount,
) {
  const gap = 12.0;
  const headerStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w900);
  const numberStyle = TextStyle(
    color: Color(0xFF111820),
    fontSize: 11,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0,
  );
  const suffixStyle = TextStyle(
    color: Colors.black,
    fontSize: 11,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0,
    shadows: _receiptAlphabetShadow,
  );
  const amountStyle = TextStyle(
    color: Color(0xFF111820),
    fontSize: 11,
    fontWeight: FontWeight.w900,
    height: 1,
    letterSpacing: 0,
  );
  const totalStyle = TextStyle(
    color: Color(0xFF111820),
    fontSize: 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );
  var numberWidth =
      _measurePrintedParchiText(context.tr('NUMBER'), headerStyle, context);
  var amountWidth =
      _measurePrintedParchiText(context.tr('AMT'), headerStyle, context);
  numberWidth = math.max(
    numberWidth,
    _measurePrintedParchiText(context.tr('TOTAL'), totalStyle, context),
  );
  amountWidth = math.max(
    amountWidth,
    _measurePrintedParchiText(
      AppLocalizations.localizeDigits(totalAmount),
      totalStyle,
      context,
    ),
  );

  for (final pageItem in items) {
    final number = formatParchiNumber(
      pageItem.item,
      pageItem.item.sessionOverride ?? session,
    );
    if (pageItem.showMainEntry) {
      numberWidth = math.max(
        numberWidth,
        _measurePrintedParchiTextSpan(
          _printedParchiNumberSpan(number, numberStyle, suffixStyle),
          context,
        ),
      );
      amountWidth = math.max(
        amountWidth,
        _measurePrintedParchiText(
          AppLocalizations.localizeDigits(
            pageItem.item.effectiveDisplayAmount,
          ),
          amountStyle,
          context,
        ),
      );
    }
    for (final entry in pageItem.jackpotEntries) {
      numberWidth = math.max(
        numberWidth,
        _measurePrintedParchiText(number.trimRight(), numberStyle, context),
      );
      amountWidth = math.max(
        amountWidth,
        _measurePrintedParchiText(
          AppLocalizations.localizeDigits(entry.amount),
          amountStyle,
          context,
        ),
      );
    }
  }

  final maxNumberWidth = math.max(1.0, 186 - gap - amountWidth);
  return _PrintedParchiColumnMetrics(
    numberWidth: math.min(numberWidth, maxNumberWidth),
    amountWidth: amountWidth,
    gap: gap,
  );
}

TextSpan _printedParchiNumberSpan(
  String number,
  TextStyle numberStyle,
  TextStyle suffixStyle,
) {
  return TextSpan(
    children: [
      if (number.startsWith('>')) TextSpan(text: '> ', style: suffixStyle),
      TextSpan(
        text: AppLocalizations.localizeDigits(_displayNumberMain(number)),
        style: numberStyle,
      ),
      if (_displayNumberSuffix(number).isNotEmpty)
        TextSpan(text: ' ${_displayNumberSuffix(number)}', style: suffixStyle),
      if (number.endsWith('>')) TextSpan(text: ' >', style: suffixStyle),
    ],
  );
}

double _measurePrintedParchiText(
  String value,
  TextStyle style,
  BuildContext context,
) {
  return _measurePrintedParchiTextSpan(
    TextSpan(text: value, style: style),
    context,
  );
}

double _measurePrintedParchiTextSpan(
  InlineSpan span,
  BuildContext context,
) {
  final painter = TextPainter(
    text: span,
    maxLines: 1,
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling,
  )..layout();
  return painter.width;
}

String _displayNumberMain(String text) {
  final parts = NumberDisplayParts.fromDisplay(text);
  return parts.beforeSuffix;
}

String _displayNumberSuffix(String text) {
  final parts = NumberDisplayParts.fromDisplay(text);
  return parts.suffix;
}

class _ParchiRule extends StatelessWidget {
  const _ParchiRule();

  @override
  Widget build(BuildContext context) {
    return Container(height: 2, color: const Color(0xFF111820));
  }
}

class _ReceiptBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF939AA3)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const step = 8.0;
    const depth = 3.0;

    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, depth), Offset(x + step / 2, 0), paint);
      canvas.drawLine(Offset(x + step / 2, 0), Offset(x + step, depth), paint);
      canvas.drawLine(Offset(x, size.height - depth),
          Offset(x + step / 2, size.height), paint);
      canvas.drawLine(Offset(x + step / 2, size.height),
          Offset(x + step, size.height - depth), paint);
    }
    canvas.drawLine(
        const Offset(0, depth), Offset(0, size.height - depth), paint);
    canvas.drawLine(Offset(size.width, depth),
        Offset(size.width, size.height - depth), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: entryLine),
    borderRadius: BorderRadius.circular(5),
  );
}

String _entryMode(ReceiptDetail detail) {
  final types =
      detail.items.map((item) => item.displayType.toLowerCase()).toSet();
  if (types.length <= 1 &&
      (types.contains('single') || types.contains('jodi'))) {
    return 'Manual Entry';
  }
  return 'Auto Entry';
}
