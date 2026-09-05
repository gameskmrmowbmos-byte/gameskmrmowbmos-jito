import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/data/receipt_repository.dart';
import 'package:matka_management/features/printed_receipts/data/print_repository.dart';
import 'package:matka_management/features/printed_receipts/services/customer_parchi_printer.dart';

final entriesControllerProvider =
    StateNotifierProvider<EntriesController, EntriesState>((ref) {
  final controller = EntriesController(
    ref.read(receiptRepositoryProvider),
    ref.read(printRepositoryProvider),
    ref.read(authProvider).user?.ownerName,
  );
  controller.loadInitial();
  return controller;
});

class EntriesState {
  const EntriesState({
    required this.filters,
    required this.page,
    required this.limit,
    required this.receipts,
    required this.markets,
    this.total = 0,
    this.totalPages = 1,
    this.selected,
    this.loading = false,
    this.detailLoading = false,
    this.cancelling = false,
    this.reprinting = false,
    this.error,
  });

  final ReceiptFilters filters;
  final int page;
  final int limit;
  final List<ReceiptSummary> receipts;
  final List<ReceiptMarket> markets;
  final int total;
  final int totalPages;
  final ReceiptDetail? selected;
  final bool loading;
  final bool detailLoading;
  final bool cancelling;
  final bool reprinting;
  final String? error;

  EntriesState copyWith({
    ReceiptFilters? filters,
    int? page,
    int? limit,
    List<ReceiptSummary>? receipts,
    List<ReceiptMarket>? markets,
    int? total,
    int? totalPages,
    ReceiptDetail? selected,
    bool clearSelected = false,
    bool? loading,
    bool? detailLoading,
    bool? cancelling,
    bool? reprinting,
    String? error,
    bool clearError = false,
  }) {
    return EntriesState(
      filters: filters ?? this.filters,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      receipts: receipts ?? this.receipts,
      markets: markets ?? this.markets,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      selected: clearSelected ? null : selected ?? this.selected,
      loading: loading ?? this.loading,
      detailLoading: detailLoading ?? this.detailLoading,
      cancelling: cancelling ?? this.cancelling,
      reprinting: reprinting ?? this.reprinting,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class EntriesController extends StateNotifier<EntriesState> {
  EntriesController(this._repository, this._printRepository, this._ownerName)
      : super(
          EntriesState(
            filters: ReceiptFilters.defaults(),
            page: 1,
            limit: 10,
            receipts: const [],
            markets: const [],
          ),
        );

  final ReceiptRepository _repository;
  final PrintRepository _printRepository;
  final String? _ownerName;

  Future<void> loadInitial() async {
    await Future.wait([loadMarkets(), loadReceipts()]);
  }

  Future<void> loadMarkets() async {
    try {
      final markets = await _repository.getMarkets();
      state = state.copyWith(markets: markets);
    } on Object {
      state = state.copyWith(markets: const []);
    }
  }

  Future<void> loadReceipts({int? page}) async {
    final nextPage = page ?? state.page;
    state = state.copyWith(loading: true, clearError: true, page: nextPage);
    try {
      final result = await _repository.getReceipts(
        filters: state.filters,
        page: nextPage,
        limit: state.limit,
      );
      state = state.copyWith(
        loading: false,
        receipts: result.receipts,
        page: result.page,
        total: result.total,
        totalPages: result.totalPages,
        clearError: true,
      );
      final selected = state.selected;
      if (selected == null && result.receipts.isNotEmpty) {
        await selectReceipt(result.receipts.first.id);
      } else if (selected != null) {
        final stillVisible =
            result.receipts.any((item) => item.id == selected.receipt.id);
        if (!stillVisible && result.receipts.isNotEmpty) {
          await selectReceipt(result.receipts.first.id);
        }
      }
    } on Object catch (error) {
      state = state.copyWith(
        loading: false,
        error: error.toString(),
      );
    }
  }

  void updateFilters(ReceiptFilters filters) {
    state = state.copyWith(filters: filters, page: 1);
    loadReceipts(page: 1);
  }

  Future<void> search() => loadReceipts(page: 1);

  Future<void> clearFilters() async {
    state = state.copyWith(filters: ReceiptFilters.defaults(), page: 1);
    await loadReceipts(page: 1);
  }

  Future<void> selectReceipt(String id) async {
    if (state.selected?.receipt.id == id && !state.detailLoading) return;
    state = state.copyWith(detailLoading: true, clearError: true);
    try {
      final detail = await _repository.getReceiptById(id);
      state = state.copyWith(
        selected: detail,
        detailLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(detailLoading: false, error: error.toString());
    }
  }

  Future<void> cancelSelected(String reason) async {
    final selected = state.selected;
    if (selected == null || selected.receipt.isCancelled) return;
    state = state.copyWith(cancelling: true, clearError: true);
    try {
      await _repository.cancelReceipt(
        receiptId: selected.receipt.id,
        reason: reason,
      );
      final detail = await _repository.getReceiptById(selected.receipt.id);
      state = state.copyWith(
        cancelling: false,
        selected: detail,
        clearError: true,
      );
      await loadReceipts(page: state.page);
    } on Object catch (error) {
      state = state.copyWith(cancelling: false, error: error.toString());
    }
  }

  Future<void> reprintSelected(String reason) async {
    final selected = state.selected;
    if (selected == null || selected.receipt.isCancelled) return;
    state = state.copyWith(reprinting: true, clearError: true);
    final printSession = prepareCustomerParchiPrint();
    try {
      Object? printError;
      var printed = false;
      try {
        await printSession.printReceipt(selected, ownerName: _ownerName);
        printed = true;
      } on Object catch (error) {
        printError = error;
      }
      await _printRepository.createDuplicatePrint(
        receiptId: selected.receipt.id,
        reason: reason,
        status: printed ? 'Success' : 'Failed',
        errorMessage: printError?.toString(),
      );
      final detail = await _repository.getReceiptById(selected.receipt.id);
      state = state.copyWith(
        selected: detail,
        reprinting: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(reprinting: false, error: error.toString());
    }
  }
}
