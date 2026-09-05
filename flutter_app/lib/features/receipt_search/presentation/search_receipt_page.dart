import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/presentation/receipt_detail_widgets.dart';
import 'package:matka_management/features/receipt_search/presentation/search_receipt_controller.dart';

class SearchReceiptPage extends ConsumerStatefulWidget {
  const SearchReceiptPage({super.key});

  @override
  ConsumerState<SearchReceiptPage> createState() => _SearchReceiptPageState();
}

class _SearchReceiptPageState extends ConsumerState<SearchReceiptPage> {
  final _queryController = TextEditingController();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchReceiptControllerProvider);
    final compact = MediaQuery.sizeOf(context).width < 700;
    if (_queryController.text != state.query) {
      _queryController.text = state.query;
    }
    return ColoredBox(
      color: const Color(0xFFF8FAFD),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 24),
        child: compact ? _mobile(state) : _desktop(state),
      ),
    );
  }

  Widget _desktop(SearchReceiptState state) {
    final detail = state.detail;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EntryPageHeader(
          icon: Icons.search,
          title: 'Search Receipt',
          subtitle: 'Search and verify any receipt',
        ),
        const SizedBox(height: 24),
        _searchPanel(state, compact: false),
        const SizedBox(height: 22),
        if (state.error != null) _MessagePanel(state.error!, color: entryRed),
        if (state.message != null)
          _MessagePanel(state.message!, color: entryBlue),
        Expanded(
          child: detail == null
              ? _emptyState(state)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 300,
                      child: _resultCard(detail),
                    ),
                    const SizedBox(width: 22),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NumberedTitle('3', 'Parchi Details'),
                          const SizedBox(height: 10),
                          ReceiptItemsTable(items: detail.consolidatedItems),
                          const SizedBox(height: 16),
                          const NumberedTitle('4', 'Print History'),
                          const SizedBox(height: 10),
                          PrintHistoryView(logs: detail.printLogs),
                          const Spacer(),
                          _actions(detail),
                        ],
                      ),
                    ),
                    const SizedBox(width: 22),
                    SizedBox(
                      width: 360,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NumberedTitle('5', 'Parchi Preview'),
                          const SizedBox(height: 10),
                          Expanded(
                            child: SingleChildScrollView(
                              child: PrintedReceiptPreview(detail: detail),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _mobile(SearchReceiptState state) {
    final detail = state.detail;
    return ListView(
      children: [
        _searchPanel(state, compact: true),
        const SizedBox(height: 18),
        if (state.error != null) _MessagePanel(state.error!, color: entryRed),
        if (state.message != null)
          _MessagePanel(state.message!, color: entryBlue),
        if (state.loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (state.mobileMatches.isNotEmpty && detail == null)
          _mobileMatches(state.mobileMatches),
        if (detail != null) ...[
          _resultCard(detail),
          const SizedBox(height: 12),
          _mobileSection(
            title: '3. Parchi Details',
            child: ReceiptDetailsPanel(
              detail: detail,
              showActions: false,
            ),
          ),
          _mobileSection(
            title: '4. Print History',
            child: PrintHistoryView(logs: detail.printLogs, compact: true),
          ),
          _mobileSection(
            title: '5. Parchi Preview',
            child: PrintedReceiptPreview(detail: detail),
          ),
          const SizedBox(height: 10),
          const NumberedTitle('6', 'Actions'),
          const SizedBox(height: 8),
          _actions(detail, compact: true),
        ],
        if (!state.loading && detail == null && state.mobileMatches.isEmpty)
          _emptyState(state),
      ],
    );
  }

  Widget _searchPanel(SearchReceiptState state, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NumberedTitle('1', 'Search By'),
        const SizedBox(height: 12),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: SearchMethod.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (context, index) {
              final method = SearchMethod.values[index];
              final selected = state.method == method;
              return SizedBox(
                width: compact ? 112 : 130,
                child: OutlinedButton(
                  onPressed: () {
                    _queryController.clear();
                    ref
                        .read(searchReceiptControllerProvider.notifier)
                        .setMethod(method);
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: selected ? entryBlue : Colors.white,
                    foregroundColor: selected ? Colors.white : Colors.black,
                    side: BorderSide(color: selected ? entryBlue : entryLine),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  child: Text(
                    method.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        if (compact)
          Column(
            children: [
              _queryField(state),
              const SizedBox(height: 10),
              _searchButtons(state, compact: true),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 4, child: _queryField(state)),
              const SizedBox(width: 14),
              _searchButtons(state, compact: false),
              const SizedBox(width: 28),
              const Expanded(child: _QuickTips()),
            ],
          ),
        const SizedBox(height: 8),
        Text(
          state.method == SearchMethod.qrCode
              ? 'Paste QR content containing a receipt number or verification URL.'
              : 'Example: RC-030826-0012',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
      ],
    );
  }

  Widget _queryField(SearchReceiptState state) {
    return TextField(
      controller: _queryController,
      textInputAction: TextInputAction.search,
      onChanged: (value) =>
          ref.read(searchReceiptControllerProvider.notifier).setQuery(value),
      onSubmitted: (_) =>
          ref.read(searchReceiptControllerProvider.notifier).search(),
      decoration: InputDecoration(
        labelText: state.method == SearchMethod.receiptNumber
            ? 'Receipt Number'
            : state.method.label,
        hintText: state.method.hint,
        prefixIcon: Icon(
          state.method == SearchMethod.qrCode
              ? Icons.qr_code_scanner
              : state.method == SearchMethod.printId
                  ? Icons.print_outlined
                  : state.method == SearchMethod.mobile
                      ? Icons.phone_android
                      : Icons.receipt_long_outlined,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(5)),
      ),
    );
  }

  Widget _searchButtons(SearchReceiptState state, {required bool compact}) {
    return SizedBox(
      width: compact ? double.infinity : 270,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: state.loading
                    ? null
                    : () => ref
                        .read(searchReceiptControllerProvider.notifier)
                        .search(),
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: state.loading
                    ? null
                    : () {
                        _queryController.clear();
                        ref
                            .read(searchReceiptControllerProvider.notifier)
                            .clear();
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('Clear'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(ReceiptDetail detail) {
    final receipt = detail.receipt;
    final color = receipt.isCancelled
        ? entryRed
        : detail.isDuplicateLookup
            ? entryOrange
            : entryGreen;
    final title = receipt.isCancelled
        ? 'Receipt Found'
        : detail.isDuplicateLookup
            ? 'Valid Receipt'
            : 'Receipt Found';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: color, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              StatusBadge(receipt.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            receipt.receiptNumber,
            style: const TextStyle(
              color: entryBlue,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _miniInfo(Icons.calendar_month_outlined, formatDate(receipt.date)),
          _miniInfo(Icons.schedule, formatTime(receipt.date)),
          _miniInfo(
            Icons.sell_outlined,
            '${receipt.market?.name ?? '-'} - ${receipt.session.toUpperCase()}',
          ),
          _miniInfo(Icons.person_outline, receipt.operator?.name ?? '-'),
          _miniInfo(
            Icons.receipt_long_outlined,
            'Items: ${receipt.totalItems}    Amount: $rupee ${receipt.totalAmountText}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(receipt.printStatus),
              if (detail.isDuplicateLookup)
                const StatusBadge('Duplicate Print'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileMatches(List<ReceiptSummary> receipts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NumberedTitle('2', 'Matching Receipts'),
        const SizedBox(height: 8),
        for (final receipt in receipts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
                side: const BorderSide(color: entryLine),
              ),
              child: ListTile(
                title: Text(
                  receipt.receiptNumber,
                  style: const TextStyle(
                    color: entryBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                subtitle: Text(
                  '${formatDateTime(receipt.date)}\n${receipt.market?.name ?? '-'} - ${receipt.session.toUpperCase()}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => ref
                    .read(searchReceiptControllerProvider.notifier)
                    .selectReceipt(receipt.id),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(ReceiptDetail detail, {bool compact = false}) {
    final state = ref.watch(searchReceiptControllerProvider);
    final buttons = [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: detail.receipt.isCancelled || state.reprinting
              ? null
              : () => _reprintDialog(),
          icon: state.reprinting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.print_outlined),
          label: const Text('Reprint Receipt'),
        ),
      ),
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () {
            _queryController.clear();
            ref.read(searchReceiptControllerProvider.notifier).clear();
          },
          icon: const Icon(Icons.close),
          label: const Text('Close'),
        ),
      ),
    ];
    if (compact) {
      return Row(children: [buttons[0], const SizedBox(width: 10), buttons[1]]);
    }
    return Row(children: [buttons[0], const SizedBox(width: 28), buttons[1]]);
  }

  Future<void> _reprintDialog() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reprint Receipt'),
        content: TextField(
          controller: controller,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Duplicate print reason',
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
    await ref.read(searchReceiptControllerProvider.notifier).reprint(reason);
  }

  Widget _mobileSection({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: const BorderSide(color: entryLine),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            title,
            style:
                const TextStyle(color: entryBlue, fontWeight: FontWeight.w900),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(SearchReceiptState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Search for a receipt to verify its status.'),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.black87),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTips extends StatelessWidget {
  const _QuickTips();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E8),
        border: Border.all(color: const Color(0xFFF8C471)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        'Quick Tips\nEnter the full receipt number for quick search.\nQR mode accepts pasted scanner text.\nPrint ID search resolves the related receipt.',
        style: TextStyle(height: 1.45),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel(this.message, {required this.color});

  final String message;
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
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
