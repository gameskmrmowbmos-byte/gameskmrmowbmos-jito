import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/widgets/loading_view.dart';
import 'package:matka_management/features/share_records/presentation/providers/share_records_provider.dart';
import 'package:matka_management/features/share_records/presentation/widgets/a4_record_page_widget.dart';
import 'package:matka_management/features/share_records/services/share_records_export_service.dart';

const Color _bluePrimary = Color(0xFF064DB5);
const Color _greenPrimary = Color(0xFF16A34A);

class ShareRecordsPage extends ConsumerStatefulWidget {
  const ShareRecordsPage({super.key});

  @override
  ConsumerState<ShareRecordsPage> createState() => _ShareRecordsPageState();
}

class _ShareRecordsPageState extends ConsumerState<ShareRecordsPage>
    with SingleTickerProviderStateMixin {
  final Map<int, GlobalKey> _pageKeys = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shareRecordsControllerProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  GlobalKey _keyForPage(int pageIndex) {
    return _pageKeys.putIfAbsent(pageIndex, () => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(shareRecordsControllerProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    return ColoredBox(
      color: const Color(0xFFF8FAFD),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main UI Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, state, isMobile: isMobile),
                const SizedBox(height: 16),
                _buildFiltersBar(context, state, isMobile: isMobile),
                const SizedBox(height: 16),
                if (state.error != null) ...[
                  _buildErrorBanner(state.error!),
                  const SizedBox(height: 12),
                ],
                if (state.statusMessage != null) ...[
                  _buildStatusBanner(state.statusMessage!),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: state.loading
                      ? const LoadingView(label: 'Loading share records...')
                      : state.pages.isEmpty
                          ? _buildEmptyState()
                          : isMobile
                              ? _buildMobileTabsLayout(state)
                              : _buildDesktopLayout(state),
                ),
              ],
            ),
          ),

          // Hidden rendering tree for exports. It is painted outside the viewport
          // so RepaintBoundary can capture real pixels without affecting layout.
          if (state.pages.isNotEmpty)
            Positioned(
              left: -20000,
              top: 0,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < state.pages.length; i++)
                      RepaintBoundary(
                        key: _keyForPage(i),
                        child: A4RecordPageWidget(
                          pageData: state.pages[i],
                          width: A4RecordPageWidget.exportWidth,
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

  Widget _buildHeader(BuildContext context, ShareRecordsState state,
      {required bool isMobile}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('SHARE RECORDS'),
                style: const TextStyle(
                  color: _bluePrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context
                    .tr('Generate and export A4 record sheets as PDF or PNG'),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile)
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _bluePrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    onPressed:
                        state.exporting || state.sharing || state.pages.isEmpty
                            ? null
                            : () => _downloadAllPagesPdf(state),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(
                      context.tr('Download PDF'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    onPressed:
                        state.exporting || state.sharing || state.pages.isEmpty
                            ? null
                            : () => _downloadAllPages(state),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(
                      context.tr('Download PNG'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _greenPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    onPressed:
                        state.exporting || state.sharing || state.pages.isEmpty
                            ? null
                            : () => _shareAllPages(state),
                    icon: const Icon(Icons.share, size: 18),
                    label: Text(
                      context.tr('Share WhatsApp'),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                    ),
                    onPressed: state.loading || state.exporting || state.sharing
                        ? null
                        : () => ref
                            .read(shareRecordsControllerProvider.notifier)
                            .loadRecords(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text(context.tr('Refresh')),
                  ),
                ],
              ),
            ),
          ),
        if (isMobile)
          IconButton(
            tooltip: context.tr('Refresh'),
            onPressed: state.loading || state.exporting || state.sharing
                ? null
                : () => ref
                    .read(shareRecordsControllerProvider.notifier)
                    .loadRecords(),
            icon: const Icon(Icons.refresh, color: _bluePrimary),
          ),
      ],
    );
  }

  Widget _buildFiltersBar(BuildContext context, ShareRecordsState state,
      {required bool isMobile}) {
    final notifier = ref.read(shareRecordsControllerProvider.notifier);
    final dateStr = AppLocalizations.localizeDigits(
      DateFormat('dd-MM-yyyy').format(state.filterDate),
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          // Date Filter
          SizedBox(
            width: isMobile ? double.infinity : 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('DATE'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size.fromHeight(42),
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: state.filterDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) notifier.setFilterDate(picked);
                  },
                  icon: const Icon(Icons.calendar_month,
                      size: 18, color: _bluePrimary),
                  label: Text(dateStr,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A))),
                ),
              ],
            ),
          ),

          // Market Filter
          SizedBox(
            width: isMobile ? double.infinity : 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('MARKET'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: ValueKey('market-${state.selectedMarketId ?? ''}'),
                  initialValue: state.selectedMarketId ?? '',
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(context.tr('ALL MARKETS')),
                    ),
                    for (final market in state.markets)
                      DropdownMenuItem(
                        value: market.id,
                        child: Text(
                          AppLocalizations.localizeMarketName(market.name),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (val) => notifier.setMarketId(val),
                ),
              ],
            ),
          ),

          // Session Filter
          SizedBox(
            width: isMobile ? double.infinity : 170,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('SESSION'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  key: ValueKey('session-${state.selectedSession}'),
                  initialValue: state.selectedSession,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'Open', child: Text(context.tr('OPEN'))),
                    DropdownMenuItem(
                        value: 'Close', child: Text(context.tr('CLOSE'))),
                    DropdownMenuItem(
                      value: 'All',
                      child: Text(context.tr('ALL SESSIONS')),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) notifier.setSession(val);
                  },
                ),
              ],
            ),
          ),

          // Search Button
          SizedBox(
            width: isMobile ? double.infinity : 140,
            height: 42,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _bluePrimary),
              onPressed: state.loading || state.exporting || state.sharing
                  ? null
                  : () => notifier.loadRecords(),
              icon: const Icon(Icons.search, size: 18),
              label: Text(
                context.tr('Search'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),

          // Clear Button
          SizedBox(
            width: isMobile ? double.infinity : 110,
            height: 42,
            child: OutlinedButton(
              onPressed: state.loading || state.exporting || state.sharing
                  ? null
                  : () => notifier.clearFilters(),
              child: Text(context.tr('Clear')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(ShareRecordsState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: 1. OVERALL PREVIEW (ALL PAGES) (~28% width)
        Expanded(
          flex: 28,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.tr('1. OVERALL PREVIEW (ALL PAGES)'),
                  style: const TextStyle(
                    color: _bluePrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(
                    'Total Pages : {pages}',
                    params: {'pages': state.totalPages},
                  ),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 12),

                // Vertical List of Page Thumbnails
                Expanded(
                  child: ListView.builder(
                    itemCount: state.totalPages,
                    itemBuilder: (context, index) {
                      final isSelected = index == state.selectedPageIndex;
                      final pageData = state.pages[index];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () => ref
                              .read(shareRecordsControllerProvider.notifier)
                              .selectPage(index),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _bluePrimary.withValues(alpha: 0.05)
                                  : const Color(0xFFFAFAFA),
                              border: Border.all(
                                color: isSelected
                                    ? _bluePrimary
                                    : const Color(0xFFCBD5E1),
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.tr(
                                    'Page {page}',
                                    params: {'page': pageData.pageNumber},
                                  ),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    color: isSelected
                                        ? _bluePrimary
                                        : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AspectRatio(
                                  aspectRatio: 1.414,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(
                                          color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.contain,
                                      child: A4RecordPageWidget(
                                        pageData: pageData,
                                        width: A4RecordPageWidget.exportWidth,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),
                // Left Column Action Buttons
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _bluePrimary),
                  onPressed: state.exporting || state.sharing
                      ? null
                      : () => _downloadAllPages(state),
                  icon: const Icon(Icons.download, size: 18),
                  label: Text(
                    context.tr('Download All Pages (PNG)'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: state.exporting || state.sharing
                      ? null
                      : () => _downloadAllPagesPdf(state),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(
                    context.tr('Download All Pages (PDF)'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _greenPrimary),
                  onPressed: state.exporting || state.sharing
                      ? null
                      : () => _shareAllPages(state),
                  icon: const Icon(Icons.share, size: 18),
                  label: Text(
                    context.tr('Share All Pages on WhatsApp'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.tr(
                    'Note: Each page contains max 10 records arranged in 2 rows and 5 columns.',
                  ),
                  style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 16),

        // Right Column: 2. SINGLE PAGE PREVIEW (~72% width)
        Expanded(
          flex: 72,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSinglePageHeaderControls(state),
                const SizedBox(height: 16),

                // Large Fitted Single Page Preview
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1.414,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: state.selectedPage != null
                              ? A4RecordPageWidget(
                                  pageData: state.selectedPage!,
                                  width: A4RecordPageWidget.exportWidth,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSinglePageHeaderControls(ShareRecordsState state) {
    final notifier = ref.read(shareRecordsControllerProvider.notifier);

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          context.tr('2. SINGLE PAGE PREVIEW'),
          style: const TextStyle(
              color: _bluePrimary, fontSize: 13, fontWeight: FontWeight.w900),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.tr('Page '),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(
              width: 64,
              height: 36,
              child: DropdownButtonFormField<int>(
                initialValue: state.selectedPageIndex,
                decoration: const InputDecoration(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (int i = 0; i < state.totalPages; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(AppLocalizations.localizeDigits('${i + 1}')),
                    ),
                ],
                onChanged: (val) {
                  if (val != null) notifier.selectPage(val);
                },
              ),
            ),
            Text(
              context.tr(' of {total}', params: {'total': state.totalPages}),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            _HeaderIconButton(
              tooltip: context.tr('First page'),
              icon: Icons.first_page,
              onPressed: state.selectedPageIndex == 0
                  ? null
                  : () => notifier.firstPage(),
            ),
            _HeaderIconButton(
              tooltip: context.tr('Previous page'),
              icon: Icons.chevron_left,
              onPressed: state.selectedPageIndex == 0
                  ? null
                  : () => notifier.previousPage(),
            ),
            _HeaderIconButton(
              tooltip: context.tr('Next page'),
              icon: Icons.chevron_right,
              onPressed: state.selectedPageIndex >= state.totalPages - 1
                  ? null
                  : () => notifier.nextPage(),
            ),
            _HeaderIconButton(
              tooltip: context.tr('Last page'),
              icon: Icons.last_page,
              onPressed: state.selectedPageIndex >= state.totalPages - 1
                  ? null
                  : () => notifier.lastPage(),
            ),
          ],
        ),
        _HeaderIconButton(
          tooltip: context.tr('Download this page as PNG'),
          icon: Icons.download,
          onPressed:
              state.exporting || state.sharing || state.selectedPage == null
                  ? null
                  : () => _downloadSinglePage(state),
        ),
        _HeaderIconButton(
          tooltip: context.tr('Download this page as PDF'),
          icon: Icons.picture_as_pdf_outlined,
          onPressed:
              state.exporting || state.sharing || state.selectedPage == null
                  ? null
                  : () => _downloadSinglePagePdf(state),
        ),
        _HeaderIconButton(
          tooltip: context.tr('Share this page'),
          icon: Icons.share,
          filled: true,
          onPressed:
              state.exporting || state.sharing || state.selectedPage == null
                  ? null
                  : () => _shareSinglePage(state),
        ),
      ],
    );
  }

  Widget _buildMobileTabsLayout(ShareRecordsState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight && constraints.maxHeight < 80) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: _bluePrimary,
              unselectedLabelColor: const Color(0xFF64748B),
              indicatorColor: _bluePrimary,
              tabs: [
                Tab(text: context.tr('All Pages')),
                Tab(text: context.tr('Single Page')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // All Pages Tab
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.totalPages,
                          itemBuilder: (context, index) {
                            final pageData = state.pages[index];
                            final isSelected = index == state.selectedPageIndex;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                    color: isSelected
                                        ? _bluePrimary
                                        : const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        context.tr(
                                          'Page {page} of {total}',
                                          params: {
                                            'page': pageData.pageNumber,
                                            'total': state.totalPages,
                                          },
                                        ),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13),
                                      ),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {
                                          ref
                                              .read(
                                                  shareRecordsControllerProvider
                                                      .notifier)
                                              .selectPage(index);
                                          _tabController.animateTo(1);
                                        },
                                        child: Text(context.tr('View Full')),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AspectRatio(
                                    aspectRatio: 1.414,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(
                                            color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.contain,
                                        child: A4RecordPageWidget(
                                          pageData: pageData,
                                          width: A4RecordPageWidget.exportWidth,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: _bluePrimary),
                                onPressed: state.exporting ||
                                        state.sharing ||
                                        state.pages.isEmpty
                                    ? null
                                    : () => _downloadAllPages(state),
                                icon: const Icon(Icons.download, size: 16),
                                label: Text(context.tr('PNG')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: state.exporting ||
                                        state.sharing ||
                                        state.pages.isEmpty
                                    ? null
                                    : () => _downloadAllPagesPdf(state),
                                icon: const Icon(Icons.picture_as_pdf_outlined,
                                    size: 16),
                                label: Text(context.tr('PDF')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                    backgroundColor: _greenPrimary),
                                onPressed: state.exporting ||
                                        state.sharing ||
                                        state.pages.isEmpty
                                    ? null
                                    : () => _shareAllPages(state),
                                icon: const Icon(Icons.share, size: 16),
                                label: Text(context.tr('Share')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Single Page Tab
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: state.selectedPageIndex == 0
                                ? null
                                : () => ref
                                    .read(
                                        shareRecordsControllerProvider.notifier)
                                    .previousPage(),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            context.tr(
                              'Page {page} of {total}',
                              params: {
                                'page': state.selectedPageIndex + 1,
                                'total': state.totalPages,
                              },
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          IconButton(
                            onPressed: state.selectedPageIndex >=
                                    state.totalPages - 1
                                ? null
                                : () => ref
                                    .read(
                                        shareRecordsControllerProvider.notifier)
                                    .nextPage(),
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: InteractiveViewer(
                          maxScale: 3.0,
                          minScale: 1.0,
                          child: SingleChildScrollView(
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: state.selectedPage != null
                                  ? A4RecordPageWidget(
                                      pageData: state.selectedPage!,
                                      width: A4RecordPageWidget.exportWidth,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: state.exporting ||
                                      state.sharing ||
                                      state.selectedPage == null
                                  ? null
                                  : () => _downloadSinglePage(state),
                              icon: const Icon(Icons.download, size: 16),
                              label: Text(context.tr('PNG')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: state.exporting ||
                                      state.sharing ||
                                      state.selectedPage == null
                                  ? null
                                  : () => _downloadSinglePagePdf(state),
                              icon: const Icon(Icons.picture_as_pdf_outlined,
                                  size: 16),
                              label: Text(context.tr('PDF')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: _greenPrimary),
                              onPressed: state.exporting ||
                                      state.sharing ||
                                      state.selectedPage == null
                                  ? null
                                  : () => _shareSinglePage(state),
                              icon: const Icon(Icons.share, size: 16),
                              label: Text(context.tr('Share')),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.style_outlined, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 16),
          Text(
            context.tr('No Records Found'),
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF334155)),
          ),
          const SizedBox(height: 6),
          Text(
            context.tr(
              'No records are available for the selected date, market and session.',
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.trMaybe(message),
              style: const TextStyle(
                  color: Color(0xFFB91C1C), fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                ref.read(shareRecordsControllerProvider.notifier).clearStatus(),
            icon: const Icon(Icons.close, size: 16, color: Color(0xFFDC2626)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        border: Border.all(color: const Color(0xFF86EFAC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              color: Color(0xFF16A34A), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.trMaybe(message),
              style: const TextStyle(
                  color: Color(0xFF15803D), fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadSinglePage(ShareRecordsState state) async {
    final notifier = ref.read(shareRecordsControllerProvider.notifier);
    final page = state.selectedPage;
    if (page == null) return;

    notifier.setExporting(
      true,
      message: AppLocalizations.trCurrent(
        'Generating PNG file for Page {page}...',
        params: {'page': page.pageNumber},
      ),
    );
    try {
      final key = _keyForPage(page.pageIndex);
      final pngBytes = await ShareRecordsExportService.capturePngFromKey(key);
      if (pngBytes == null) {
        if (!mounted) return;
        throw Exception(
            AppLocalizations.trCurrent('Failed to capture page image'));
      }

      final dateFormatted = DateFormat('yyyy-MM-dd').format(state.filterDate);
      final marketSanitized =
          ShareRecordsExportService.sanitizeFilename(page.marketName);
      final sessionSanitized =
          ShareRecordsExportService.sanitizeFilename(page.sessionName);
      final pageNum = page.pageNumber.toString().padLeft(2, '0');
      final filename =
          'matka-records-$dateFormatted-$marketSanitized-$sessionSanitized-page-$pageNum.png';

      final savedPath = await ShareRecordsExportService.savePngFile(
        pngBytes: pngBytes,
        filename: filename,
      );

      notifier.setExporting(
        false,
        message: AppLocalizations.trCurrent(
          'Saved PNG successfully to: {path}',
          params: {'path': savedPath},
        ),
      );
    } catch (e) {
      notifier.setExporting(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Failed to save single page PNG: {error}',
              params: {'error': e},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _downloadAllPages(ShareRecordsState state) async {
    final notifier = ref.read(shareRecordsControllerProvider.notifier);
    if (state.pages.isEmpty) return;

    notifier.setExporting(
      true,
      message: AppLocalizations.trCurrent(
        'Generating PNGs for all {pages} pages...',
        params: {'pages': state.totalPages},
      ),
    );
    try {
      final pngPages = <int, Uint8List>{};
      final failedToCaptureAnyPageMessage =
          AppLocalizations.trCurrent('Failed to capture any page images');
      for (int i = 0; i < state.pages.length; i++) {
        notifier.setExporting(
          true,
          message: AppLocalizations.trCurrent(
            'Generating PNG for Page {page} of {total}...',
            params: {'page': i + 1, 'total': state.totalPages},
          ),
        );
        final key = _keyForPage(i);
        final bytes = await ShareRecordsExportService.capturePngFromKey(key);
        if (bytes != null) pngPages[i] = bytes;
      }

      if (pngPages.isEmpty) {
        if (!mounted) return;
        throw Exception(failedToCaptureAnyPageMessage);
      }

      final dateFormatted = DateFormat('yyyy-MM-dd').format(state.filterDate);
      final savedPaths = <String>[];
      for (final entry in pngPages.entries) {
        final page = state.pages[entry.key];
        final marketSanitized =
            ShareRecordsExportService.sanitizeFilename(page.marketName);
        final sessionSanitized =
            ShareRecordsExportService.sanitizeFilename(page.sessionName);
        final pageNum = page.pageNumber.toString().padLeft(2, '0');
        final filename =
            'matka-records-$dateFormatted-$marketSanitized-$sessionSanitized-page-$pageNum.png';
        notifier.setExporting(
          true,
          message: AppLocalizations.trCurrent(
            'Downloading Page {page} PNG...',
            params: {'page': page.pageNumber},
          ),
        );
        final savedPath = await ShareRecordsExportService.savePngFile(
          pngBytes: entry.value,
          filename: filename,
        );
        savedPaths.add(savedPath);
      }

      notifier.setExporting(
        false,
        message: AppLocalizations.trCurrent(
          'Saved {count} PNG file(s) successfully',
          params: {'count': savedPaths.length},
        ),
      );
    } catch (e) {
      notifier.setExporting(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.trCurrent(
              'Failed to download all pages: {error}',
              params: {'error': e},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _downloadSinglePagePdf(ShareRecordsState state) async {
    final notifier = ref.read(shareRecordsControllerProvider.notifier);
    final page = state.selectedPage;
    if (page == null) return;

    notifier.setExporting(
      true,
      message: AppLocalizations.trCurrent(
        'Generating PDF for Page {page}...',
        params: {'page': page.pageNumber},
      ),
    );
    try {
      final key = _keyForPage(page.pageIndex);
      final failedToCaptureMessage =
          AppLocalizations.trCurrent('Failed to capture page image');
      final pngBytes = await ShareRecordsExportService.capturePngFromKey(
        key,
        pixelRatio: 2.0,
      );
      if (pngBytes == null) {
        if (!mounted) return;
        throw Exception(failedToCaptureMessage);
      }

      final pdfBytes =
          await ShareRecordsExportService.buildPdfFromPngPages([pngBytes]);
      final dateFormatted = DateFormat('yyyy-MM-dd').format(state.filterDate);
      final marketSanitized =
          ShareRecordsExportService.sanitizeFilename(page.marketName);
      final sessionSanitized =
          ShareRecordsExportService.sanitizeFilename(page.sessionName);
      final pageNum = page.pageNumber.toString().padLeft(2, '0');
      final filename =
          'matka-records-$dateFormatted-$marketSanitized-$sessionSanitized-page-$pageNum.pdf';

      final savedPath = await ShareRecordsExportService.savePdfFile(
        pdfBytes: pdfBytes,
        filename: filename,
      );

      notifier.setExporting(
        false,
        message: AppLocalizations.trCurrent(
          'Saved PDF successfully to: {path}',
          params: {'path': savedPath},
        ),
      );
    } catch (e) {
      notifier.setExporting(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.trCurrent(
              'Failed to save single page PDF: {error}',
              params: {'error': e},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _downloadAllPagesPdf(ShareRecordsState state) async {
    final notifier = ref.read(shareRecordsControllerProvider.notifier);
    if (state.pages.isEmpty) return;

    notifier.setExporting(
      true,
      message: AppLocalizations.trCurrent(
        'Generating PDF for all {pages} pages...',
        params: {'pages': state.totalPages},
      ),
    );
    try {
      final pngPages = <Uint8List>[];
      final failedToCaptureAnyMessage =
          AppLocalizations.trCurrent('Failed to capture any page images');
      for (int i = 0; i < state.pages.length; i++) {
        notifier.setExporting(
          true,
          message: AppLocalizations.trCurrent(
            'Rendering Page {page} of {total} for PDF...',
            params: {'page': i + 1, 'total': state.totalPages},
          ),
        );
        final key = _keyForPage(i);
        final bytes = await ShareRecordsExportService.capturePngFromKey(
          key,
          pixelRatio: 2.0,
        );
        if (bytes != null) pngPages.add(bytes);
      }

      if (pngPages.isEmpty) {
        if (!mounted) return;
        throw Exception(failedToCaptureAnyMessage);
      }

      notifier.setExporting(
        true,
        message: AppLocalizations.trCurrent('Writing PDF file...'),
      );
      final pdfBytes =
          await ShareRecordsExportService.buildPdfFromPngPages(pngPages);
      final dateFormatted = DateFormat('yyyy-MM-dd').format(state.filterDate);
      final marketSanitized = ShareRecordsExportService.sanitizeFilename(
          state.pages.first.marketName);
      final sessionSanitized = ShareRecordsExportService.sanitizeFilename(
          state.pages.first.sessionName);
      final filename =
          'matka-records-$dateFormatted-$marketSanitized-$sessionSanitized.pdf';

      final savedPath = await ShareRecordsExportService.savePdfFile(
        pdfBytes: pdfBytes,
        filename: filename,
      );

      notifier.setExporting(
        false,
        message: AppLocalizations.trCurrent(
          'Saved PDF successfully to: {path}',
          params: {'path': savedPath},
        ),
      );
    } catch (e) {
      notifier.setExporting(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.trCurrent(
              'Failed to download PDF: {error}',
              params: {'error': e},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _shareSinglePage(ShareRecordsState state) async {
    final notifier = ref.read(shareRecordsControllerProvider.notifier);
    final page = state.selectedPage;
    if (page == null) return;

    notifier.setSharing(
      true,
      message: AppLocalizations.trCurrent(
        'Preparing Page {page} for sharing...',
        params: {'page': page.pageNumber},
      ),
    );
    try {
      final key = _keyForPage(page.pageIndex);
      final pngBytes = await ShareRecordsExportService.capturePngFromKey(key);
      if (pngBytes == null) {
        if (!mounted) return;
        throw Exception(
            AppLocalizations.trCurrent('Failed to capture page image'));
      }

      final dateFormatted = DateFormat('yyyy-MM-dd').format(state.filterDate);
      final marketSanitized =
          ShareRecordsExportService.sanitizeFilename(page.marketName);
      final sessionSanitized =
          ShareRecordsExportService.sanitizeFilename(page.sessionName);
      final pageNum = page.pageNumber.toString().padLeft(2, '0');
      final filename =
          'matka-records-$dateFormatted-$marketSanitized-$sessionSanitized-page-$pageNum.png';

      await ShareRecordsExportService.shareSinglePage(
        pngBytes: pngBytes,
        filename: filename,
        title: AppLocalizations.trCurrent(
          'Matka Entry System - Bet Records Page {page}',
          params: {'page': page.pageNumber},
        ),
      );

      notifier.setSharing(false);
    } catch (e) {
      notifier.setSharing(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.trCurrent(
              'Failed to share single page: {error}',
              params: {'error': e},
            ),
          ),
        ),
      );
    }
  }

  Future<void> _shareAllPages(ShareRecordsState state) async {
    final notifier = ref.read(shareRecordsControllerProvider.notifier);
    if (state.pages.isEmpty) return;

    notifier.setSharing(
      true,
      message: AppLocalizations.trCurrent(
        'Preparing {pages} pages for sharing...',
        params: {'pages': state.totalPages},
      ),
    );
    try {
      final pngPages = <Uint8List>[];
      final failedToCaptureAnyPageMessage =
          AppLocalizations.trCurrent('Failed to capture page images');
      for (int i = 0; i < state.pages.length; i++) {
        final key = _keyForPage(i);
        final bytes = await ShareRecordsExportService.capturePngFromKey(key);
        if (bytes != null) pngPages.add(bytes);
      }

      if (pngPages.isEmpty) {
        if (!mounted) return;
        throw Exception(failedToCaptureAnyPageMessage);
      }

      final dateFormatted = DateFormat('yyyy-MM-dd').format(state.filterDate);
      final marketSanitized = ShareRecordsExportService.sanitizeFilename(
          state.pages.first.marketName);
      final sessionSanitized = ShareRecordsExportService.sanitizeFilename(
          state.pages.first.sessionName);
      final baseFilename =
          'matka-records-$dateFormatted-$marketSanitized-$sessionSanitized';

      await ShareRecordsExportService.shareAllPages(
        pngPages: pngPages,
        baseFilename: baseFilename,
        title: AppLocalizations.trCurrent(
          'Matka Entry System - All Bet Records ({pages} Pages)',
          params: {'pages': pngPages.length},
        ),
      );

      notifier.setSharing(false);
    } catch (e) {
      notifier.setSharing(false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.trCurrent(
              'Failed to share all pages: {error}',
              params: {'error': e},
            ),
          ),
        ),
      );
    }
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled ? _greenPrimary : Colors.white;
    final foreground = filled ? Colors.white : _bluePrimary;
    return Tooltip(
      message: context.trMaybe(tooltip),
      child: SizedBox.square(
        dimension: 38,
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          color: foreground,
          disabledColor: const Color(0xFF94A3B8),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          style: IconButton.styleFrom(
            backgroundColor:
                onPressed == null ? const Color(0xFFE5E7EB) : background,
            side: BorderSide(
              color: filled ? background : const Color(0xFFCBD5E1),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
      ),
    );
  }
}
