import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/share_records/data/share_records_models.dart';
import 'package:matka_management/features/share_records/data/share_records_repository.dart';
import 'package:matka_management/features/share_records/domain/share_records_chunker.dart';

class ShareRecordsState {
  const ShareRecordsState({
    required this.filterDate,
    this.selectedMarketId,
    this.selectedSession = 'Open',
    this.markets = const [],
    this.records = const [],
    this.pages = const [],
    this.summary,
    this.selectedPageIndex = 0,
    this.loading = false,
    this.error,
    this.exporting = false,
    this.sharing = false,
    this.statusMessage,
  });

  final DateTime filterDate;
  final String? selectedMarketId;
  final String selectedSession; // 'All', 'Open', 'Close'
  final List<ReceiptMarket> markets;
  final List<ShareRecordEntry> records;
  final List<A4RecordPageData> pages;
  final ShareRecordSummary? summary;
  final int selectedPageIndex;
  final bool loading;
  final String? error;
  final bool exporting;
  final bool sharing;
  final String? statusMessage;

  int get totalPages => pages.length;
  A4RecordPageData? get selectedPage => (pages.isNotEmpty &&
          selectedPageIndex >= 0 &&
          selectedPageIndex < pages.length)
      ? pages[selectedPageIndex]
      : null;

  ShareRecordsState copyWith({
    DateTime? filterDate,
    String? selectedMarketId,
    bool clearMarket = false,
    String? selectedSession,
    List<ReceiptMarket>? markets,
    List<ShareRecordEntry>? records,
    List<A4RecordPageData>? pages,
    ShareRecordSummary? summary,
    int? selectedPageIndex,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? exporting,
    bool? sharing,
    String? statusMessage,
    bool clearStatusMessage = false,
  }) {
    return ShareRecordsState(
      filterDate: filterDate ?? this.filterDate,
      selectedMarketId:
          clearMarket ? null : selectedMarketId ?? this.selectedMarketId,
      selectedSession: selectedSession ?? this.selectedSession,
      markets: markets ?? this.markets,
      records: records ?? this.records,
      pages: pages ?? this.pages,
      summary: summary ?? this.summary,
      selectedPageIndex: selectedPageIndex ?? this.selectedPageIndex,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      exporting: exporting ?? this.exporting,
      sharing: sharing ?? this.sharing,
      statusMessage:
          clearStatusMessage ? null : statusMessage ?? this.statusMessage,
    );
  }
}

final shareRecordsControllerProvider =
    StateNotifierProvider<ShareRecordsNotifier, ShareRecordsState>((ref) {
  final repo = ref.watch(shareRecordsRepositoryProvider);
  return ShareRecordsNotifier(repo);
});

class ShareRecordsNotifier extends StateNotifier<ShareRecordsState> {
  ShareRecordsNotifier(this._repository)
      : super(ShareRecordsState(filterDate: DateTime.now())) {
    init();
  }

  final ShareRecordsRepository _repository;

  Future<void> init() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final markets = await _repository.getMarkets();
      state = state.copyWith(markets: markets);
      await loadRecords();
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to load initial data',
      );
    }
  }

  Future<void> loadRecords() async {
    state = state.copyWith(
        loading: true, clearError: true, clearStatusMessage: true);
    try {
      final response = await _repository.getShareRecords(
        date: state.filterDate,
        marketId: state.selectedMarketId,
        session: state.selectedSession,
      );

      final selectedMarket = state.markets.firstWhere(
        (m) => m.id == state.selectedMarketId,
        orElse: () =>
            const ReceiptMarket(id: '', name: 'ALL MARKETS', code: ''),
      );

      final pages = ShareRecordsChunker.buildPages(
        records: response.records,
        filterDate: state.filterDate,
        marketName: state.selectedMarketId != null
            ? selectedMarket.name
            : 'ALL MARKETS',
        sessionName: state.selectedSession,
      );

      state = state.copyWith(
        loading: false,
        records: response.records,
        summary: response.summary,
        pages: pages,
        selectedPageIndex: 0,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Failed to fetch share records',
      );
    }
  }

  void setFilterDate(DateTime date) {
    state = state.copyWith(filterDate: date);
  }

  void setMarketId(String? marketId) {
    state = state.copyWith(
      selectedMarketId: marketId,
      clearMarket: marketId == null || marketId.isEmpty,
    );
  }

  void setSession(String session) {
    state = state.copyWith(selectedSession: session);
  }

  void clearFilters() {
    state = state.copyWith(
      filterDate: DateTime.now(),
      clearMarket: true,
      selectedSession: 'Open',
    );
    loadRecords();
  }

  void selectPage(int pageIndex) {
    if (pageIndex >= 0 && pageIndex < state.totalPages) {
      state = state.copyWith(selectedPageIndex: pageIndex);
    }
  }

  void nextPage() {
    if (state.selectedPageIndex < state.totalPages - 1) {
      selectPage(state.selectedPageIndex + 1);
    }
  }

  void previousPage() {
    if (state.selectedPageIndex > 0) {
      selectPage(state.selectedPageIndex - 1);
    }
  }

  void firstPage() {
    if (state.totalPages > 0) selectPage(0);
  }

  void lastPage() {
    if (state.totalPages > 0) selectPage(state.totalPages - 1);
  }

  void setExporting(bool value, {String? message}) {
    state = state.copyWith(
      exporting: value,
      statusMessage: message,
      clearStatusMessage: message == null,
    );
  }

  void setSharing(bool value, {String? message}) {
    state = state.copyWith(
      sharing: value,
      statusMessage: message,
      clearStatusMessage: message == null,
    );
  }

  void clearStatus() {
    state = state.copyWith(clearStatusMessage: true, clearError: true);
  }
}
