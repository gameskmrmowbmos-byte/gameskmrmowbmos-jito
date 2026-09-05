import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/entries/data/receipt_repository.dart';

final searchReceiptControllerProvider =
    StateNotifierProvider<SearchReceiptController, SearchReceiptState>((ref) {
  return SearchReceiptController(ref.read(receiptRepositoryProvider));
});

enum SearchMethod { receiptNumber, qrCode, printId, mobile }

extension SearchMethodLabel on SearchMethod {
  String get label {
    switch (this) {
      case SearchMethod.receiptNumber:
        return 'Parchi No.';
      case SearchMethod.qrCode:
        return 'QR Code';
      case SearchMethod.printId:
        return 'Print ID';
      case SearchMethod.mobile:
        return 'Mobile No.';
    }
  }

  String get hint {
    switch (this) {
      case SearchMethod.receiptNumber:
        return 'Enter receipt number';
      case SearchMethod.qrCode:
        return 'Paste or scan QR text';
      case SearchMethod.printId:
        return 'Enter print ID';
      case SearchMethod.mobile:
        return 'Enter mobile number';
    }
  }
}

class SearchReceiptState {
  const SearchReceiptState({
    this.method = SearchMethod.receiptNumber,
    this.query = '',
    this.detail,
    this.mobileMatches = const [],
    this.loading = false,
    this.reprinting = false,
    this.error,
    this.message,
  });

  final SearchMethod method;
  final String query;
  final ReceiptDetail? detail;
  final List<ReceiptSummary> mobileMatches;
  final bool loading;
  final bool reprinting;
  final String? error;
  final String? message;

  SearchReceiptState copyWith({
    SearchMethod? method,
    String? query,
    ReceiptDetail? detail,
    bool clearDetail = false,
    List<ReceiptSummary>? mobileMatches,
    bool? loading,
    bool? reprinting,
    String? error,
    String? message,
    bool clearError = false,
    bool clearMessage = false,
  }) {
    return SearchReceiptState(
      method: method ?? this.method,
      query: query ?? this.query,
      detail: clearDetail ? null : detail ?? this.detail,
      mobileMatches: mobileMatches ?? this.mobileMatches,
      loading: loading ?? this.loading,
      reprinting: reprinting ?? this.reprinting,
      error: clearError ? null : error ?? this.error,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

class SearchReceiptController extends StateNotifier<SearchReceiptState> {
  SearchReceiptController(this._repository) : super(const SearchReceiptState());

  final ReceiptRepository _repository;

  void setMethod(SearchMethod method) {
    state = state.copyWith(
      method: method,
      query: '',
      clearDetail: true,
      mobileMatches: const [],
      clearError: true,
      clearMessage: true,
    );
  }

  void setQuery(String value) {
    state = state.copyWith(query: value, clearError: true, clearMessage: true);
  }

  void clear() {
    state = SearchReceiptState(method: state.method);
  }

  Future<void> search() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      state = state.copyWith(error: 'Enter a search value');
      return;
    }
    state = state.copyWith(
      loading: true,
      clearError: true,
      clearMessage: true,
      clearDetail: true,
      mobileMatches: const [],
    );
    try {
      switch (state.method) {
        case SearchMethod.receiptNumber:
          final detail = await _repository.searchReceiptNumber(query);
          state = state.copyWith(loading: false, detail: detail);
          break;
        case SearchMethod.qrCode:
          final detail = await _repository.searchQrText(query);
          state = state.copyWith(loading: false, detail: detail);
          break;
        case SearchMethod.printId:
          final detail = await _repository.searchPrintId(query);
          state = state.copyWith(loading: false, detail: detail);
          break;
        case SearchMethod.mobile:
          final result = await _repository.searchMobile(query);
          state = state.copyWith(
            loading: false,
            mobileMatches: result.receipts,
            message: result.receipts.isEmpty
                ? 'No receipts found for this mobile number'
                : null,
          );
          if (result.receipts.length == 1) {
            await selectReceipt(result.receipts.first.id);
          }
          break;
      }
    } on Object catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> selectReceipt(String id) async {
    state = state.copyWith(loading: true, clearError: true, clearMessage: true);
    try {
      final detail = await _repository.getReceiptById(id);
      state = state.copyWith(loading: false, detail: detail);
    } on Object catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> reprint(String reason) async {
    final detail = state.detail;
    if (detail == null) return;
    if (detail.receipt.isCancelled) {
      state = state.copyWith(error: 'Cancelled receipts cannot be reprinted');
      return;
    }
    state = state.copyWith(reprinting: true, clearError: true);
    try {
      await _repository.reprintReceipt(
        receiptId: detail.receipt.id,
        reason: reason,
      );
      final refreshed = await _repository.getReceiptById(detail.receipt.id);
      state = state.copyWith(
        reprinting: false,
        detail: refreshed,
        message: 'Duplicate print recorded',
      );
    } on Object catch (error) {
      state = state.copyWith(reprinting: false, error: error.toString());
    }
  }
}
