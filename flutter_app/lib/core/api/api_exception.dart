import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException(this.message,
      {this.statusCode, this.code, this.fieldErrors = const {}});

  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, String> fieldErrors;

  factory ApiException.fromDio(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      final rawErrors = responseData['errors'];
      final errors = <String, String>{};
      if (rawErrors is List) {
        for (final item in rawErrors.whereType<Map>()) {
          final field = item['field']?.toString();
          final message = item['message']?.toString();
          if (field != null && message != null) errors[field] = message;
        }
      }
      final message = responseData['message']?.toString() ?? 'Request failed';
      return ApiException(
        errors.isEmpty
            ? message
            : errors.entries
                .map((entry) => '${entry.key}: ${entry.value}')
                .join(', '),
        statusCode: error.response?.statusCode,
        code: responseData['code']?.toString(),
        fieldErrors: errors,
      );
    }
    return ApiException(
      error.type == DioExceptionType.connectionError
          ? 'Cannot connect to the API. Check the backend URL and network.'
          : error.message ?? 'Request failed',
      statusCode: error.response?.statusCode,
    );
  }

  @override
  String toString() => message;
}
