import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:matka_management/core/api/api_client.dart';
import 'package:matka_management/core/api/api_endpoints.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>(
  (ref) => ReceiptRepository(ref.read(apiClientProvider)),
);

class ReceiptFilters {
  const ReceiptFilters({
    this.fromDate,
    this.toDate,
    this.marketId,
    this.session,
    this.receiptNumber = '',
    this.number = '',
    this.receiptStatus,
    this.printStatus,
    this.customerMobile = '',
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final String? marketId;
  final String? session;
  final String receiptNumber;
  final String number;
  final String? receiptStatus;
  final String? printStatus;
  final String customerMobile;

  ReceiptFilters copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? marketId,
    String? session,
    String? receiptNumber,
    String? number,
    String? receiptStatus,
    String? printStatus,
    String? customerMobile,
    bool clearMarket = false,
    bool clearSession = false,
    bool clearReceiptStatus = false,
    bool clearPrintStatus = false,
  }) {
    return ReceiptFilters(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      marketId: clearMarket ? null : marketId ?? this.marketId,
      session: clearSession ? null : session ?? this.session,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      number: number ?? this.number,
      receiptStatus:
          clearReceiptStatus ? null : receiptStatus ?? this.receiptStatus,
      printStatus: clearPrintStatus ? null : printStatus ?? this.printStatus,
      customerMobile: customerMobile ?? this.customerMobile,
    );
  }

  Map<String, dynamic> toQuery({required int page, required int limit}) {
    final date = DateFormat('yyyy-MM-dd');
    return {
      'page': page,
      'limit': limit,
      if (fromDate != null) 'fromDate': date.format(fromDate!),
      if (toDate != null) 'toDate': date.format(toDate!),
      if (marketId != null && marketId!.isNotEmpty) 'market': marketId,
      if (session != null && session!.isNotEmpty) 'session': session,
      if (receiptStatus != null && receiptStatus!.isNotEmpty)
        'status': receiptStatus,
      if (printStatus != null && printStatus!.isNotEmpty)
        'printStatus': printStatus,
      if (receiptNumber.trim().isNotEmpty)
        'receiptNumber': receiptNumber.trim(),
      if (number.trim().isNotEmpty) 'number': number.trim(),
      if (customerMobile.trim().isNotEmpty)
        'customerMobile': customerMobile.trim(),
    };
  }

  static ReceiptFilters defaults() {
    final now = DateTime.now();
    return ReceiptFilters(
      fromDate: DateTime(now.year, now.month, now.day - 7),
      toDate: DateTime(now.year, now.month, now.day),
    );
  }
}

class ReceiptRepository {
  const ReceiptRepository(this._api);

  final ApiClient _api;

  Future<ReceiptPageResult> getReceipts({
    required ReceiptFilters filters,
    required int page,
    required int limit,
  }) async {
    final response = await _api.getJson(
      ApiEndpoints.receipts,
      query: filters.toQuery(page: page, limit: limit),
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final pagination =
        response['pagination'] as Map<String, dynamic>? ?? const {};
    final receipts = (data['receipts'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReceiptSummary.fromJson)
        .toList();
    return ReceiptPageResult(
      receipts: receipts,
      page: _intValue(pagination['page'], fallback: page),
      limit: _intValue(pagination['limit'], fallback: limit),
      total: _intValue(pagination['total']),
      totalPages: _intValue(pagination['totalPages'], fallback: 1),
    );
  }

  Future<ReceiptDetail> createReceipt({
    required String market,
    required String session,
    required List<Map<String, dynamic>> items,
    String? customerName,
    String? customerMobile,
    String? notes,
    bool isOtc = false,
  }) async {
    final response = await _api.sendJson(
      'POST',
      ApiEndpoints.receipts,
      data: {
        'market': market,
        'session': session,
        'items': items,
        'isOtc': isOtc,
        if (customerName != null && customerName.trim().isNotEmpty)
          'customerName': customerName.trim(),
        if (customerMobile != null && customerMobile.trim().isNotEmpty)
          'customerMobile': customerMobile.trim(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return ReceiptDetail.fromJson(data);
  }

  Future<ReceiptDetail> getReceiptById(String id) async {
    final response = await _api.getJson('${ApiEndpoints.receipts}/$id');
    return ReceiptDetail.fromJson(response);
  }

  Future<ReceiptDetail> searchReceiptNumber(String receiptNumber) async {
    final response = await _api.getJson(
      ApiEndpoints.receiptSearch,
      query: {
        'method': 'receiptNumber',
        'query': receiptNumber.trim(),
      },
    );
    return ReceiptDetail.fromJson(response);
  }

  Future<ReceiptDetail> searchPrintId(String printId) async {
    final response = await _api.getJson(
      ApiEndpoints.printSearch,
      query: {'printId': printId.trim()},
    );
    return ReceiptDetail.fromJson(response);
  }

  Future<List<ReceiptMarket>> getMarkets() async {
    final response = await _api.getJson(
      ApiEndpoints.markets,
      query: {'status': 'active', 'limit': 100},
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return (data['markets'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ReceiptMarket.fromJson)
        .toList();
  }

  Future<void> cancelReceipt({
    required String receiptId,
    required String reason,
  }) async {
    await _api.sendJson(
      'POST',
      '${ApiEndpoints.receipts}/$receiptId/cancel',
      data: {'reason': reason.trim()},
    );
  }

  Future<void> deleteReceipt({required String receiptId}) async {
    await _api.sendJson(
      'DELETE',
      '${ApiEndpoints.receipts}/$receiptId',
    );
  }

  Future<PrintLogModel> reprintReceipt({
    required String receiptId,
    required String reason,
    String printerName = '',
  }) async {
    final response = await _api.sendJson(
      'POST',
      ApiEndpoints.prints,
      data: {
        'receiptId': receiptId,
        'printType': 'Duplicate',
        'printerName': printerName,
        'status': 'Success',
        'reprintReason': reason.trim(),
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return PrintLogModel.fromJson(
      data['printLog'] as Map<String, dynamic>? ?? const {},
    );
  }
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
