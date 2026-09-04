import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/printed_receipts/data/print_repository.dart';
import 'package:matka_management/features/printed_receipts/services/customer_parchi_printer.dart';

final printedReceiptsControllerProvider =
    StateNotifierProvider<PrintedReceiptsController, PrintedReceiptsState>(
        (ref) {
  final controller = PrintedReceiptsController(
    ref.read(printRepositoryProvider),
    isAdmin: ref.read(authProvider).user?.isAdmin == true,
  );
  controller.loadInitial();
  return controller;
});

class PrintedReceiptsState {
  const PrintedReceiptsState({
    required this.filters,
    required this.page,
    required this.limit,
    required this.logs,
    required this.markets,
    required this.operators,
    this.total = 0,
    this.totalPages = 1,
    this.selected,
    this.loading = false,
    this.detailLoading = false,
    this.reprinting = false,
    this.retrying = false,
    this.error,
  });

  final PrintFilters filters;
  final int page;
  final int limit;
  final List<PrintLogModel> logs;
  final List<ReceiptMarket> markets;
  final List<OperatorOption> operators;
  final int total;
  final int totalPages;
  final ReceiptDetail? selected;
  final bool loading;
  final bool detailLoading;
  final bool reprinting;
  final bool retrying;
  final String? error;

  PrintedReceiptsState copyWith({
    PrintFilters? filters,
    int? page,
    int? limit,
    List<PrintLogModel>? logs,
    List<ReceiptMarket>? markets,
    List<OperatorOption>? operators,
    int? total,
    int? totalPages,
    ReceiptDetail? selected,
    bool clearSelected = false,
    bool? loading,
    bool? detailLoading,
    bool? reprinting,
    bool? retrying,
    String? error,
    bool clearError = false,
  }) {
    return PrintedReceiptsState(
      filters: filters ?? this.filters,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      logs: logs ?? this.logs,
      markets: markets ?? this.markets,
      operators: operators ?? this.operators,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      selected: clearSelected ? null : selected ?? this.selected,
      loading: loading ?? this.loading,
      detailLoading: detailLoading ?? this.detailLoading,
      reprinting: reprinting ?? this.reprinting,
      retrying: retrying ?? this.retrying,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class PrintedReceiptsController extends StateNotifier<PrintedReceiptsState> {
  PrintedReceiptsController(this._repository, {required this.isAdmin})
      : super(
          PrintedReceiptsState(
            filters: PrintFilters.defaults(),
            page: 1,
            limit: 10,
            logs: const [],
            markets: const [],
            operators: const [],
          ),
        );

  final PrintRepository _repository;
  final bool isAdmin;

  Future<void> loadInitial() async {
    await Future.wait([loadLookups(), loadPrintLogs()]);
  }

  Future<void> loadLookups() async {
    try {
      final results = await Future.wait([
        _repository.getMarkets(),
        if (isAdmin)
          _repository.getOperators()
        else
          Future<List<OperatorOption>>.value(const []),
      ]);
      state = state.copyWith(
        markets: results[0] as List<ReceiptMarket>,
        operators: results[1] as List<OperatorOption>,
      );
    } on Object {
      state = state.copyWith(markets: const [], operators: const []);
    }
  }

  Future<void> loadPrintLogs({int? page}) async {
    final nextPage = page ?? state.page;
    state = state.copyWith(loading: true, clearError: true, page: nextPage);
    try {
      final result = await _repository.getPrintLogs(
        filters: state.filters,
        page: nextPage,
        limit: state.limit,
      );
      state = state.copyWith(
        loading: false,
        logs: result.logs,
        page: result.page,
        total: result.total,
        totalPages: result.totalPages,
        clearError: true,
      );
      if (state.selected == null && result.logs.isNotEmpty) {
        await selectPrint(result.logs.first.id);
      }
    } on Object catch (error) {
      state = state.copyWith(
        loading: false,
        error: error.toString(),
      );
    }
  }

  void updateFilters(PrintFilters filters) {
    state = state.copyWith(filters: filters, page: 1);
  }

  Future<void> search() => loadPrintLogs(page: 1);

  Future<void> clearFilters() async {
    state = state.copyWith(filters: PrintFilters.defaults(), page: 1);
    await loadPrintLogs(page: 1);
  }

  Future<void> selectPrint(String id) async {
    if (state.selected?.matchedPrintLog?.id == id && !state.detailLoading) {
      return;
    }
    state = state.copyWith(detailLoading: true, clearError: true);
    try {
      final detail = await _repository.getPrintLogById(id);
      state = state.copyWith(
        selected: detail,
        detailLoading: false,
        clearError: true,
      );
    } on Object catch (error) {
      state = state.copyWith(detailLoading: false, error: error.toString());
    }
  }

  Future<void> reprintSelected(String reason) async {
    final selected = state.selected;
    if (selected == null || selected.receipt.isCancelled) return;
    final printSession = prepareCustomerParchiPrint();
    state = state.copyWith(reprinting: true, clearError: true);
    try {
      Object? printError;
      var printed = false;
      try {
        await printSession.printReceipt(selected);
        printed = true;
      } on Object catch (error) {
        printError = error;
      }
      await _repository.createDuplicatePrint(
        receiptId: selected.receipt.id,
        reason: reason,
        status: printed ? 'Success' : 'Failed',
        errorMessage: printError?.toString(),
      );
      await loadPrintLogs(page: state.page);
      await selectPrint(selected.matchedPrintLog?.id ?? selected.receipt.id);
      state = state.copyWith(reprinting: false);
    } on Object catch (error) {
      state = state.copyWith(reprinting: false, error: error.toString());
    }
  }

  Future<void> retrySelected(String reason) async {
    final selected = state.selected;
    if (selected == null || selected.receipt.isCancelled) return;
    final printSession = prepareCustomerParchiPrint();
    state = state.copyWith(retrying: true, clearError: true);
    try {
      Object? printError;
      var printed = false;
      try {
        await printSession.printReceipt(selected);
        printed = true;
      } on Object catch (error) {
        printError = error;
      }
      await _repository.retryPrint(
        receiptId: selected.receipt.id,
        reason: reason,
        status: printed ? 'Success' : 'Failed',
        errorMessage: printError?.toString(),
      );
      await loadPrintLogs(page: state.page);
      state = state.copyWith(retrying: false);
    } on Object catch (error) {
      state = state.copyWith(retrying: false, error: error.toString());
    }
  }
}
