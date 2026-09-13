import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/presentation/parchi_receipt_widget.dart';

const entryBlue = Color(0xFF064DB5);
const entryGreen = Color(0xFF108438);
const entryRed = Color(0xFFF20D16);
const entryOrange = Color(0xFFF97316);
const entryLine = Color(0xFFD8DCE3);
const rupee = '\u20B9';
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
              AppLocalizations.localizeDigits(
                  items[index].effectiveDisplayAmount),
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
          fontWeight: header ? FontWeight.w900 : FontWeight.w500,
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
              AppLocalizations.localizeDigits(
                  '${logs[index].printNumber ?? '-'}'),
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
    return ParchiReceiptPreview(detail: detail);
  }
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
