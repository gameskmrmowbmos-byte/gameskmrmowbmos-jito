import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:matka_management/core/api/api_client.dart';
import 'package:matka_management/core/api/api_endpoints.dart';
import 'package:matka_management/features/entries/data/receipt_models.dart';
import 'package:matka_management/features/share_records/data/share_records_models.dart';

final shareRecordsRepositoryProvider = Provider<ShareRecordsRepository>(
  (ref) => ShareRecordsRepository(ref.read(apiClientProvider)),
);

class ShareRecordsRepository {
  const ShareRecordsRepository(this._api);

  final ApiClient _api;

  Future<ShareRecordResponse> getShareRecords({
    required DateTime date,
    String? marketId,
    String? session,
  }) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    final query = <String, dynamic>{
      'date': formattedDate,
      if (marketId != null && marketId.isNotEmpty) 'marketId': marketId,
      if (session != null && session.isNotEmpty && session != 'All')
        'session': session,
    };

    final response = await _api.getJson(
      ApiEndpoints.shareRecords,
      query: query,
    );

    return ShareRecordResponse.fromJson(response);
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
}
