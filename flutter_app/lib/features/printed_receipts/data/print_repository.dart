import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:matka_management/core/api/api_client.dart';
import 'package:matka_management/core/api/api_endpoints.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';

final printRepositoryProvider = Provider<PrintRepository>(
  (ref) => PrintRepository(ref.read(apiClientProvider)),
);

class PrintFilters {
  const PrintFilters({
    this.fromDate,
    this.toDate,
    this.marketId,
    this.session,
    this.receiptNumber = '',
    this.printId = '',
    this.operatorId,
    this.printType,
    this.printStatus,
    this.printerName = '',
  });

  final DateTime? fromDate;
  final DateTime? toDate;
  final String? marketId;
  final String? session;
  final String receiptNumber;
  final String printId;
  final String? operatorId;
  final String? printType;
  final String? printStatus;
  final String printerName;

  static PrintFilters defaults() {
    final now = DateTime.now();
    return PrintFilters(
      fromDate: DateTime(now.year, now.month, now.day - 7),
      toDate: DateTime(now.year, now.month, now.day),
    );
  }

  PrintFilters copyWith({
    DateTime? fromDate,
    DateTime? toDate,
    String? marketId,
    String? session,
    String? receiptNumber,
    String? printId,
    String? operatorId,
    String? printType,
    String? printStatus,
    String? printerName,
    bool clearMarket = false,
    bool clearSession = false,
    bool clearOperator = false,
    bool clearPrintType = false,
    bool clearPrintStatus = false,
  }) {
    return PrintFilters(
      fromDate: fromDate ?? this.fromDate,
      toDate: toDate ?? this.toDate,
      marketId: clearMarket ? null : marketId ?? this.marketId,
      session: clearSession ? null : session ?? this.session,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      printId: printId ?? this.printId,
      operatorId: clearOperator ? null : operatorId ?? this.operatorId,
      printType: clearPrintType ? null : printType ?? this.printType,
      printStatus: clearPrintStatus ? null : printStatus ?? this.printStatus,
      printerName: printerName ?? this.printerName,
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
      if (operatorId != null && operatorId!.isNotEmpty) 'operator': operatorId,
      if (printType != null && printType!.isNotEmpty) 'printType': printType,
      if (printStatus != null && printStatus!.isNotEmpty) 'status': printStatus,
      if (receiptNumber.trim().isNotEmpty)
        'receiptNumber': receiptNumber.trim(),
      if (printId.trim().isNotEmpty) 'printId': printId.trim(),
      if (printerName.trim().isNotEmpty) 'printerName': printerName.trim(),
    };
  }
}

class PrintPageResult {
  const PrintPageResult({
    required this.logs,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<PrintLogModel> logs;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
}

class OperatorOption {
  const OperatorOption({required this.id, required this.name});

  final String id;
  final String name;

  factory OperatorOption.fromJson(Map<String, dynamic> json) {
    return OperatorOption(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['fullName']?.toString() ?? json['username']?.toString() ?? '',
    );
  }
}

class PrintRepository {
  const PrintRepository(this._api);

  final ApiClient _api;

  Future<PrintPageResult> getPrintLogs({
    required PrintFilters filters,
    required int page,
    required int limit,
  }) async {
    final response = await _api.getJson(
      ApiEndpoints.prints,
      query: filters.toQuery(page: page, limit: limit),
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    final pagination =
        response['pagination'] as Map<String, dynamic>? ?? const {};
    final logs = (data['logs'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PrintLogModel.fromJson)
        .toList();
    return PrintPageResult(
      logs: logs,
      page: _intValue(pagination['page'], fallback: page),
      limit: _intValue(pagination['limit'], fallback: limit),
      total: _intValue(pagination['total']),
      totalPages: _intValue(pagination['totalPages'], fallback: 1),
    );
  }

  Future<ReceiptDetail> getPrintLogById(String id) async {
    final response = await _api.getJson('${ApiEndpoints.prints}/$id');
    return ReceiptDetail.fromJson(response);
  }

  Future<PrintLogModel> createDuplicatePrint({
    required String receiptId,
    required String reason,
    String status = 'Success',
    String printerName = '',
    String? errorMessage,
  }) async {
    final response = await _api.sendJson(
      'POST',
      ApiEndpoints.prints,
      data: {
        'receiptId': receiptId,
        'printType': 'Duplicate',
        'printerName': printerName,
        'printerType': 'Thermal',
        'paperSize': '58mm',
        'status': status,
        'reprintReason': reason,
        if (errorMessage != null && errorMessage.trim().isNotEmpty)
          'errorMessage': errorMessage.trim(),
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return PrintLogModel.fromJson(
      data['printLog'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<PrintLogModel> createOriginalPrint({
    required String receiptId,
    String status = 'Success',
    String printerName = '',
    String? errorMessage,
  }) async {
    final response = await _api.sendJson(
      'POST',
      ApiEndpoints.prints,
      data: {
        'receiptId': receiptId,
        'printType': 'Original',
        'printerName': printerName,
        'printerType': 'Thermal',
        'paperSize': '58mm',
        'status': status,
        if (errorMessage != null && errorMessage.trim().isNotEmpty)
          'errorMessage': errorMessage.trim(),
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return PrintLogModel.fromJson(
      data['printLog'] as Map<String, dynamic>? ?? const {},
    );
  }

  Future<PrintLogModel> retryPrint({
    required String receiptId,
    required String reason,
    String printerName = '',
    String status = 'Success',
    String? errorMessage,
  }) async {
    final response = await _api.sendJson(
      'POST',
      ApiEndpoints.prints,
      data: {
        'receiptId': receiptId,
        'printType': 'Duplicate',
        'printerName': printerName,
        'printerType': 'Thermal',
        'paperSize': '58mm',
        'status': status,
        'reprintReason': reason,
        'retryReason': reason,
        if (errorMessage != null && errorMessage.trim().isNotEmpty)
          'errorMessage': errorMessage.trim(),
      },
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return PrintLogModel.fromJson(
      data['printLog'] as Map<String, dynamic>? ?? const {},
    );
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

  Future<List<OperatorOption>> getOperators() async {
    final response = await _api.getJson(
      ApiEndpoints.users,
      query: {'limit': 100},
    );
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return (data['users'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(OperatorOption.fromJson)
        .toList();
  }
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}
