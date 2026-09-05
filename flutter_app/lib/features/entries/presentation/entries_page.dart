import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/core/widgets/loading_view.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/data/receipt_repository.dart';
import 'package:matka_management/features/entries/presentation/entries_controller.dart';
import 'package:matka_management/features/entries/presentation/receipt_detail_widgets.dart';

class EntriesPage extends ConsumerStatefulWidget {
  const EntriesPage({super.key});

  @override
  ConsumerState<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends ConsumerState<EntriesPage> {
  final _receiptController = TextEditingController();
  final _numberController = TextEditingController();

  @override
  void dispose() {
    _receiptController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(entriesControllerProvider);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 700;

    if (_receiptController.text != state.filters.receiptNumber) {
      _receiptController.text = state.filters.receiptNumber;
    }
    if (_numberController.text != state.filters.number) {
      _numberController.text = state.filters.number;
    }

    return ColoredBox(
      color: const Color(0xFFF8FAFD),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 24),
        child: compact ? _mobile(state) : _desktop(state),
      ),
    );
  }

  Widget _desktop(EntriesState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntryPageHeader(
          icon: Icons.receipt_long_outlined,
          title: 'Entries',
          subtitle: 'View and manage all saved entries',
          trailing: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.ios_share),
            label: const Text('Export'),
          ),
        ),
        const SizedBox(height: 24),
        _filters(state, compact: false),
        const SizedBox(height: 16),
        if (state.error != null) _InlineMessage(state.error!, color: entryRed),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NumberedTitle('2', 'Entries List'),
                    const SizedBox(height: 10),
                    Expanded(child: _entriesTable(state)),
                    const SizedBox(height: 12),
                    _pagination(state),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NumberedTitle('3', 'Parchi Details'),
                    const SizedBox(height: 10),
                    Expanded(child: _detailsPanel(state)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobile(EntriesState state) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(entriesControllerProvider.notifier).loadReceipts(),
      child: ListView(
        children: [
          _filters(state, compact: true),
          const SizedBox(height: 18),
          const NumberedTitle('2', 'Entries List'),
          const SizedBox(height: 10),
          if (state.error != null) ...[
            _InlineMessage(state.error!, color: entryRed),
            const SizedBox(height: 10),
          ],
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.receipts.isEmpty && state.error == null)
            const _EmptyPanel('No entries found for these filters.')
          else
            for (final receipt in state.receipts)
              _ReceiptCard(
                receipt: receipt,
                onView: () async {
                  await ref
                      .read(entriesControllerProvider.notifier)
                      .selectReceipt(receipt.id);
                  if (!mounted) return;
                  _showMobileDetail();
                },
              ),
          const SizedBox(height: 12),
          _pagination(state),
        ],
      ),
    );
  }

  Widget _filters(EntriesState state, {required bool compact}) {
    final filters = state.filters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NumberedTitle('1', 'Filters'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _DateField(
              label: 'From Date',
              value: filters.fromDate,
              width: compact ? double.infinity : 150,
              onPick: (date) => _setFilters(filters.copyWith(fromDate: date)),
            ),
            _DateField(
              label: 'To Date',
              value: filters.toDate,
              width: compact ? double.infinity : 150,
              onPick: (date) => _setFilters(filters.copyWith(toDate: date)),
            ),
            _SelectField(
              label: 'Market',
              width: compact ? double.infinity : 160,
              value: filters.marketId ?? '',
              items: {
                '': 'All Markets',
                for (final market in state.markets) market.id: market.name,
              },
              onChanged: (value) => _setFilters(
                filters.copyWith(
                  marketId: value,
                  clearMarket: value == null || value.isEmpty,
                ),
              ),
            ),
            _SelectField(
              label: 'Session',
              width: compact ? double.infinity : 140,
              value: filters.session ?? '',
              items: const {
                '': 'All Sessions',
                'Open': 'Open',
                'Close': 'Close'
              },
              onChanged: (value) => _setFilters(
                filters.copyWith(
                  session: value,
                  clearSession: value == null || value.isEmpty,
                ),
              ),
            ),
            _SelectField(
              label: 'Status',
              width: compact ? double.infinity : 140,
              value: filters.receiptStatus ?? '',
              items: const {
                '': 'All Status',
                'Active': 'Active',
                'Cancelled': 'Cancelled',
              },
              onChanged: (value) => _setFilters(
                filters.copyWith(
                  receiptStatus: value,
                  clearReceiptStatus: value == null || value.isEmpty,
                ),
              ),
            ),
            _FilterTextField(
              label: 'Parchi No.',
              controller: _receiptController,
              width: compact ? double.infinity : 160,
              onChanged: (value) => _setFilters(
                filters.copyWith(receiptNumber: value),
              ),
            ),
            _FilterTextField(
              label: 'Number',
              controller: _numberController,
              width: compact ? double.infinity : 150,
              onChanged: (value) =>
                  _setFilters(filters.copyWith(number: value)),
            ),
            _SelectField(
              label: 'Print Status',
              width: compact ? double.infinity : 190,
              value: filters.printStatus ?? '',
              items: const {
                '': 'All',
                'Printed': 'Printed',
                'Not Printed': 'Not Printed',
              },
              onChanged: (value) => _setFilters(
                filters.copyWith(
                  printStatus: value,
                  clearPrintStatus: value == null || value.isEmpty,
                ),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 130,
              height: 42,
              child: FilledButton.icon(
                onPressed: state.loading
                    ? null
                    : () =>
                        ref.read(entriesControllerProvider.notifier).search(),
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 130,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: state.loading
                    ? null
                    : () => ref
                        .read(entriesControllerProvider.notifier)
                        .clearFilters(),
                icon: const Icon(Icons.refresh),
                label: const Text('Clear'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _entriesTable(EntriesState state) {
    if (state.loading) return const LoadingView(label: 'Loading entries...');
    if (state.error != null && state.receipts.isEmpty) {
      return _EmptyPanel(state.error!);
    }
    if (state.receipts.isEmpty) {
      return const _EmptyPanel('No entries found for these filters.');
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: entryLine),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          _tableRow(
            const [
              'SR.',
              'PARCHI NO.',
              'DATE & TIME',
              'MARKET',
              'SESSION',
              'ITEMS',
              'AMOUNT ($rupee)',
              'PRINT STATUS',
              'STATUS',
              'ACTION',
            ],
            header: true,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: state.receipts.length,
              itemBuilder: (context, index) {
                final receipt = state.receipts[index];
                return InkWell(
                  onTap: () => ref
                      .read(entriesControllerProvider.notifier)
                      .selectReceipt(receipt.id),
                  child: _tableRow(
                    [
                      '${(state.page - 1) * state.limit + index + 1}',
                      receipt.receiptNumber,
                      formatDateTime(receipt.date),
                      receipt.market?.name ?? '-',
                      receipt.session.toUpperCase(),
                      '${receipt.totalItems}',
                      '${receipt.totalAmountText}${receipt.isOtc ? ' OTC' : ''}',
                      receipt.printStatus,
                      receipt.status,
                      '',
                    ],
                    receipt: receipt,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow(
    List<String> values, {
    bool header = false,
    ReceiptSummary? receipt,
  }) {
    final flexes = [1, 2, 2, 2, 1, 1, 1, 2, 2, 1];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: header ? const Color(0xFFF6F8FB) : Colors.white,
        border: Border(
            top: BorderSide(color: header ? Colors.transparent : entryLine)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              flex: flexes[i],
              child: Center(
                child: i == 7 && !header
                    ? StatusBadge(values[i])
                    : i == 8 && !header
                        ? StatusBadge(values[i])
                        : i == 9 && !header && receipt != null
                            ? IconButton(
                                tooltip: 'View receipt',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => ref
                                    .read(entriesControllerProvider.notifier)
                                    .selectReceipt(receipt.id),
                                icon: const Icon(
                                  Icons.remove_red_eye_outlined,
                                  color: entryBlue,
                                  size: 19,
                                ),
                              )
                            : Text(
                                values[i],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: header ? 11 : 12,
                                  fontWeight: header
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                ),
                              ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailsPanel(EntriesState state) {
    if (state.detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = state.selected;
    if (detail == null) {
      return const _EmptyPanel('Select a receipt to inspect.');
    }
    return ListView(
      children: [
        ReceiptDetailsPanel(
          detail: detail,
          cancelling: state.cancelling,
          onCancel: () => _confirmCancel(),
        ),
        const SizedBox(height: 14),
        const NumberedTitle('4', 'Parchi Preview'),
        const SizedBox(height: 8),
        PrintedReceiptPreview(detail: detail),
        const SizedBox(height: 14),
        const NumberedTitle('5', 'Print History'),
        const SizedBox(height: 8),
        PrintHistoryView(logs: detail.printLogs),
        const SizedBox(height: 10),
        _reprintButton(detail, state),
      ],
    );
  }

  Widget _pagination(EntriesState state) {
    final page = state.page;
    final totalPages = state.totalPages;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing ${state.receipts.length} of ${state.total} entries',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Previous page',
          onPressed: page <= 1 || state.loading
              ? null
              : () => ref
                  .read(entriesControllerProvider.notifier)
                  .loadReceipts(page: page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '$page / $totalPages',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: page >= totalPages || state.loading
              ? null
              : () => ref
                  .read(entriesControllerProvider.notifier)
                  .loadReceipts(page: page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Future<void> _showMobileDetail() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final state = ref.watch(entriesControllerProvider);
        final detail = state.selected;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.88,
          maxChildSize: 0.95,
          minChildSize: 0.45,
          builder: (context, scrollController) {
            if (detail == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              children: [
                ReceiptDetailsPanel(
                  detail: detail,
                  cancelling: state.cancelling,
                  onCancel: () => _confirmCancel(),
                ),
                const SizedBox(height: 16),
                const NumberedTitle('4', 'Parchi Preview'),
                const SizedBox(height: 8),
                PrintedReceiptPreview(detail: detail),
                const SizedBox(height: 14),
                const NumberedTitle('5', 'Print History'),
                const SizedBox(height: 8),
                PrintHistoryView(logs: detail.printLogs, compact: true),
                const SizedBox(height: 10),
                _reprintButton(detail, state),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmCancel() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Parchi'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Cancellation reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('Cancel Parchi'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await ref.read(entriesControllerProvider.notifier).cancelSelected(reason);
  }

  Widget _reprintButton(ReceiptDetail detail, EntriesState state) {
    return OutlinedButton.icon(
      onPressed: detail.receipt.isCancelled || state.reprinting
          ? null
          : () => _reprintDialog(),
      icon: state.reprinting
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.print_outlined),
      label: const Text('Reprint this receipt'),
    );
  }

  Future<void> _reprintDialog() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reprint this receipt'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Reprint reason',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.of(context).pop(value);
            },
            child: const Text('Reprint'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await ref.read(entriesControllerProvider.notifier).reprintSelected(reason);
  }

  void _setFilters(ReceiptFilters filters) {
    ref.read(entriesControllerProvider.notifier).updateFilters(filters);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.width,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final double width;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) onPick(picked);
              },
              child: Row(
                children: [
                  Expanded(child: Text(formatDate(value))),
                  const Icon(Icons.calendar_month_outlined, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.width,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final double width;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: items.containsKey(value) ? value : '',
            isExpanded: true,
            decoration: _inputDecoration(),
            items: [
              for (final entry in items.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterTextField extends StatelessWidget {
  const _FilterTextField({
    required this.label,
    required this.controller,
    required this.width,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final double width;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: _inputDecoration(),
          ),
        ],
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.receipt, required this.onView});

  final ReceiptSummary receipt;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: entryLine),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  receipt.receiptNumber,
                  style: const TextStyle(
                      color: entryBlue, fontWeight: FontWeight.w900),
                ),
              ),
              StatusBadge(receipt.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(formatDateTime(receipt.date)),
          const SizedBox(height: 5),
          Text(
              '${receipt.market?.name ?? '-'} - ${receipt.session.toUpperCase()}'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('Items: ${receipt.totalItems}')),
              Text(
                '$rupee ${receipt.totalAmountText}${receipt.isOtc ? ' OTC' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: 'View',
                onPressed: onView,
                icon:
                    const Icon(Icons.remove_red_eye_outlined, color: entryBlue),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(receipt.printStatus),
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: entryLine),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(message),
    );
  }
}

Widget _label(String text) {
  return Text(
    text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
  );
}

InputDecoration _inputDecoration() {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
  );
}
