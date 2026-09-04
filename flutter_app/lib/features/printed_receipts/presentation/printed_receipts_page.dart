import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/core/widgets/loading_view.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/presentation/receipt_detail_widgets.dart';
import 'package:matka_management/features/printed_receipts/data/print_repository.dart';
import 'package:matka_management/features/printed_receipts/presentation/printed_receipts_controller.dart';

class PrintedReceiptsPage extends ConsumerStatefulWidget {
  const PrintedReceiptsPage({super.key});

  @override
  ConsumerState<PrintedReceiptsPage> createState() =>
      _PrintedReceiptsPageState();
}

class _PrintedReceiptsPageState extends ConsumerState<PrintedReceiptsPage> {
  final _receiptController = TextEditingController();
  final _printController = TextEditingController();
  final _printerController = TextEditingController();

  @override
  void dispose() {
    _receiptController.dispose();
    _printController.dispose();
    _printerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printedReceiptsControllerProvider);
    final compact = MediaQuery.sizeOf(context).width < 700;
    _syncControllers(state.filters);
    return ColoredBox(
      color: const Color(0xFFF8FAFD),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 24),
        child: compact ? _mobile(state) : _desktop(state),
      ),
    );
  }

  Widget _desktop(PrintedReceiptsState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EntryPageHeader(
          icon: Icons.print_outlined,
          title: 'Printed Parchis',
          subtitle: 'View every physical print attempt',
        ),
        const SizedBox(height: 22),
        _filters(state, compact: false),
        const SizedBox(height: 12),
        if (state.error != null) _Message(state.error!, color: entryRed),
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 7,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NumberedTitle('2', 'Printed Parchis List'),
                    const SizedBox(height: 10),
                    Expanded(child: _table(state)),
                    const SizedBox(height: 10),
                    _pagination(state),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 360,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NumberedTitle('3', 'Print Details'),
                    const SizedBox(height: 10),
                    Expanded(child: _detail(state)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobile(PrintedReceiptsState state) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(printedReceiptsControllerProvider.notifier).loadPrintLogs(),
      child: ListView(
        children: [
          _filters(state, compact: true),
          const SizedBox(height: 16),
          const NumberedTitle('2', 'Printed Parchis'),
          const SizedBox(height: 8),
          if (state.error != null) ...[
            _Message(state.error!, color: entryRed),
            const SizedBox(height: 8),
          ],
          if (state.loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.logs.isEmpty && state.error == null)
            const _Empty('No print logs found.')
          else
            for (final log in state.logs)
              _PrintCard(
                log: log,
                onView: () async {
                  await ref
                      .read(printedReceiptsControllerProvider.notifier)
                      .selectPrint(log.id);
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

  Widget _filters(PrintedReceiptsState state, {required bool compact}) {
    final filters = state.filters;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NumberedTitle('1', 'Filters'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _DateButton(
              label: 'From Date',
              value: filters.fromDate,
              width: compact ? double.infinity : 145,
              onPick: (date) => _setFilters(filters.copyWith(fromDate: date)),
            ),
            _DateButton(
              label: 'To Date',
              value: filters.toDate,
              width: compact ? double.infinity : 145,
              onPick: (date) => _setFilters(filters.copyWith(toDate: date)),
            ),
            _Select(
              label: 'Market',
              value: filters.marketId ?? '',
              width: compact ? double.infinity : 150,
              items: {
                '': 'All Markets',
                for (final market in state.markets) market.id: market.name,
              },
              onChanged: (value) => _setFilters(filters.copyWith(
                marketId: value,
                clearMarket: value == null || value.isEmpty,
              )),
            ),
            _Select(
              label: 'Session',
              value: filters.session ?? '',
              width: compact ? double.infinity : 145,
              items: const {
                '': 'All Sessions',
                'Open': 'Open',
                'Close': 'Close'
              },
              onChanged: (value) => _setFilters(filters.copyWith(
                session: value,
                clearSession: value == null || value.isEmpty,
              )),
            ),
            _TextFilter(
              label: 'Parchi No.',
              controller: _receiptController,
              width: compact ? double.infinity : 150,
              onChanged: (value) =>
                  _setFilters(filters.copyWith(receiptNumber: value)),
            ),
            _TextFilter(
              label: 'Print ID',
              controller: _printController,
              width: compact ? double.infinity : 140,
              onChanged: (value) =>
                  _setFilters(filters.copyWith(printId: value)),
            ),
            _Select(
              label: 'Operator',
              value: filters.operatorId ?? '',
              width: compact ? double.infinity : 150,
              items: {
                '': 'All Operators',
                for (final operator in state.operators)
                  operator.id: operator.name,
              },
              onChanged: (value) => _setFilters(filters.copyWith(
                operatorId: value,
                clearOperator: value == null || value.isEmpty,
              )),
            ),
            _Select(
              label: 'Print Type',
              value: filters.printType ?? '',
              width: compact ? double.infinity : 145,
              items: const {
                '': 'All Types',
                'Original': 'Original',
                'Duplicate': 'Duplicate',
              },
              onChanged: (value) => _setFilters(filters.copyWith(
                printType: value,
                clearPrintType: value == null || value.isEmpty,
              )),
            ),
            _Select(
              label: 'Print Status',
              value: filters.printStatus ?? '',
              width: compact ? double.infinity : 145,
              items: const {
                '': 'All Status',
                'Success': 'Success',
                'Failed': 'Failed',
                'Pending': 'Pending',
              },
              onChanged: (value) => _setFilters(filters.copyWith(
                printStatus: value,
                clearPrintStatus: value == null || value.isEmpty,
              )),
            ),
            _TextFilter(
              label: 'Printer',
              controller: _printerController,
              width: compact ? double.infinity : 140,
              onChanged: (value) =>
                  _setFilters(filters.copyWith(printerName: value)),
            ),
            SizedBox(
              width: compact ? double.infinity : 130,
              height: 42,
              child: FilledButton.icon(
                onPressed: state.loading
                    ? null
                    : () => ref
                        .read(printedReceiptsControllerProvider.notifier)
                        .search(),
                icon: const Icon(Icons.search),
                label: const Text('Search', overflow: TextOverflow.ellipsis),
              ),
            ),
            SizedBox(
              width: compact ? double.infinity : 130,
              height: 42,
              child: OutlinedButton.icon(
                onPressed: state.loading
                    ? null
                    : () => ref
                        .read(printedReceiptsControllerProvider.notifier)
                        .clearFilters(),
                icon: const Icon(Icons.refresh),
                label: const Text('Clear', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _table(PrintedReceiptsState state) {
    if (state.loading) return const LoadingView(label: 'Loading print logs...');
    if (state.error != null && state.logs.isEmpty) return _Empty(state.error!);
    if (state.logs.isEmpty) return const _Empty('No print logs found.');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: entryLine),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          _row(
            const [
              'SR.',
              'PRINT ID',
              'PARCHI NO.',
              'MARKET',
              'SESSION',
              'TYPE',
              'PRINT TIME',
              'OPERATOR',
              'PRINTER',
              'STATUS',
              'ACTION',
            ],
            header: true,
          ),
          Expanded(
            child: ListView.builder(
              itemCount: state.logs.length,
              itemBuilder: (context, index) {
                final log = state.logs[index];
                return InkWell(
                  onTap: () => ref
                      .read(printedReceiptsControllerProvider.notifier)
                      .selectPrint(log.id),
                  child: _row(
                    [
                      '${(state.page - 1) * state.limit + index + 1}',
                      log.printId,
                      log.receipt?.receiptNumber ?? '-',
                      log.receipt?.market?.name ?? '-',
                      log.receipt?.session.toUpperCase() ?? '-',
                      log.printType,
                      formatDateTime(log.printedAt),
                      log.operator?.name ?? '-',
                      log.printerName,
                      log.status,
                      '',
                    ],
                    log: log,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> values, {bool header = false, PrintLogModel? log}) {
    final flexes = [1, 2, 2, 2, 1, 1, 2, 2, 2, 1, 1];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
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
                child: i == 9 && !header
                    ? StatusBadge(values[i])
                    : i == 10 && !header && log != null
                        ? IconButton(
                            tooltip: 'View print',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => ref
                                .read(
                                    printedReceiptsControllerProvider.notifier)
                                .selectPrint(log.id),
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
                              fontSize: header ? 10 : 12,
                              fontWeight:
                                  header ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _detail(PrintedReceiptsState state) {
    if (state.detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final detail = state.selected;
    final log = detail?.matchedPrintLog;
    if (detail == null || log == null) {
      return const _Empty('Select a print log.');
    }
    return ListView(
      children: [
        _PrintDetails(detail: detail, log: log),
        const SizedBox(height: 12),
        _actionButtons(detail, log),
        const SizedBox(height: 14),
        const NumberedTitle('4', 'Parchi Preview'),
        const SizedBox(height: 8),
        PrintedReceiptPreview(detail: detail),
      ],
    );
  }

  Widget _actionButtons(ReceiptDetail detail, PrintLogModel log) {
    final state = ref.watch(printedReceiptsControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: detail.receipt.isCancelled || state.reprinting
              ? null
              : () => _reasonDialog(
                    title: 'Reprint Selected',
                    label: 'Reprint reason',
                    onSubmit: (reason) => ref
                        .read(printedReceiptsControllerProvider.notifier)
                        .reprintSelected(reason),
                  ),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Reprint Selected'),
        ),
        if (log.status.toLowerCase() == 'failed') ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: state.retrying
                ? null
                : () => _reasonDialog(
                      title: 'Retry Print',
                      label: 'Retry reason',
                      onSubmit: (reason) => ref
                          .read(printedReceiptsControllerProvider.notifier)
                          .retrySelected(reason),
                    ),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Print'),
          ),
        ],
      ],
    );
  }

  Widget _pagination(PrintedReceiptsState state) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Showing ${state.logs.length} of ${state.total} print logs',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Previous page',
          onPressed: state.page <= 1 || state.loading
              ? null
              : () => ref
                  .read(printedReceiptsControllerProvider.notifier)
                  .loadPrintLogs(page: state.page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${state.page} / ${state.totalPages}',
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: state.page >= state.totalPages || state.loading
              ? null
              : () => ref
                  .read(printedReceiptsControllerProvider.notifier)
                  .loadPrintLogs(page: state.page + 1),
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
        final state = ref.watch(printedReceiptsControllerProvider);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          maxChildSize: 0.96,
          minChildSize: 0.5,
          builder: (context, controller) {
            final detail = state.selected;
            final log = detail?.matchedPrintLog;
            if (detail == null || log == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              children: [
                _PrintDetails(detail: detail, log: log),
                const SizedBox(height: 12),
                _actionButtons(detail, log),
                const SizedBox(height: 14),
                PrintedReceiptPreview(detail: detail),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _reasonDialog({
    required String title,
    required String label,
    required Future<void> Function(String reason) onSubmit,
  }) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
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
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    await onSubmit(reason);
  }

  void _syncControllers(PrintFilters filters) {
    if (_receiptController.text != filters.receiptNumber) {
      _receiptController.text = filters.receiptNumber;
    }
    if (_printController.text != filters.printId) {
      _printController.text = filters.printId;
    }
    if (_printerController.text != filters.printerName) {
      _printerController.text = filters.printerName;
    }
  }

  void _setFilters(PrintFilters filters) {
    ref.read(printedReceiptsControllerProvider.notifier).updateFilters(filters);
  }
}

class _PrintDetails extends StatelessWidget {
  const _PrintDetails({required this.detail, required this.log});

  final ReceiptDetail detail;
  final PrintLogModel log;

  @override
  Widget build(BuildContext context) {
    final receipt = detail.receipt;
    return Container(
      padding: const EdgeInsets.all(14),
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
                  log.printId,
                  style: const TextStyle(
                    color: entryBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusBadge(log.status),
            ],
          ),
          const Divider(height: 20),
          DetailRow('Parchi No.', receipt.receiptNumber),
          DetailRow('Market', receipt.market?.name ?? '-'),
          DetailRow('Session', receipt.session.toUpperCase()),
          DetailRow('Print Type', log.printType),
          DetailRow('Print No.', '${log.printNumber ?? detail.printCount}'),
          DetailRow('Print Time', formatDateTime(log.printedAt)),
          DetailRow('Operator', log.operator?.name ?? '-'),
          DetailRow('Printer', log.printerName),
          DetailRow('Printer Type', log.printerType ?? '-'),
          DetailRow('Paper Size', log.paperSize ?? '-'),
          DetailRow('Device ID', log.deviceId ?? '-'),
          DetailRow('Created At', formatDateTime(log.createdAt)),
          if (log.errorMessage != null) DetailRow('Failure', log.errorMessage!),
          if (log.reprintReason != null)
            DetailRow('Reprint Reason', log.reprintReason!),
          if (log.retryReason != null)
            DetailRow('Retry Reason', log.retryReason!),
        ],
      ),
    );
  }
}

class _PrintCard extends StatelessWidget {
  const _PrintCard({required this.log, required this.onView});

  final PrintLogModel log;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final receipt = log.receipt;
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
                  log.printId,
                  style: const TextStyle(
                      color: entryBlue, fontWeight: FontWeight.w900),
                ),
              ),
              StatusBadge(log.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(receipt?.receiptNumber ?? '-'),
          Text(
              '${receipt?.market?.name ?? '-'} - ${receipt?.session.toUpperCase() ?? '-'}'),
          const SizedBox(height: 8),
          Text('${log.printType}  ${formatDateTime(log.printedAt)}'),
          Text('${log.operator?.name ?? '-'} • ${log.printerName}'),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'View',
              onPressed: onView,
              icon: const Icon(Icons.remove_red_eye_outlined, color: entryBlue),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
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
          _fieldLabel(label),
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

class _Select extends StatelessWidget {
  const _Select({
    required this.label,
    required this.value,
    required this.width,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final double width;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(label),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: items.containsKey(value) ? value : '',
            isExpanded: true,
            decoration: _fieldDecoration(),
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

class _TextFilter extends StatelessWidget {
  const _TextFilter({
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
          _fieldLabel(label),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: _fieldDecoration(),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);

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

Widget _fieldLabel(String text) {
  return Text(
    text,
    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
  );
}

InputDecoration _fieldDecoration() {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
  );
}
