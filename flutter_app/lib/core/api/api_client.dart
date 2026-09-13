import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/core/api/api_endpoints.dart';
import 'package:matka_management/core/api/api_exception.dart';
import 'package:matka_management/core/api/http_adapter.dart';
import 'package:matka_management/core/config/api_config.dart';
import 'package:matka_management/core/storage/secure_storage_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    ref.read(secureStorageProvider),
    onUnauthorized: () {
      ref.read(authExpiredSignalProvider.notifier).state++;
    },
  );
});

final authExpiredSignalProvider = StateProvider<int>((ref) => 0);

class ApiClient {
  ApiClient(this._storage, {VoidCallback? onUnauthorized})
      : _onUnauthorized = onUnauthorized {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Accept': 'application/json',
          'X-Client-Platform': kIsWeb ? 'web' : 'native',
        },
      ),
    );
    configureHttpAdapter(_dio);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          var token = await _storage.readAccessToken();
          final canRefreshBeforeRequest = options.path != ApiEndpoints.login &&
              options.path != ApiEndpoints.refresh;
          if (canRefreshBeforeRequest &&
              token != null &&
              token.isNotEmpty &&
              _isTokenExpiredOrExpiring(token)) {
            try {
              await refreshSession();
              token = await _storage.readAccessToken();
            } on Object {
              await _storage.clear();
              _onUnauthorized?.call();
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  message: 'Session expired. Please login again.',
                ),
              );
            }
          }
          if (token != null &&
              token.isNotEmpty &&
              options.path != ApiEndpoints.login) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          if (_isTransportError(error) &&
              request.extra['apiFailoverAttempted'] != true) {
            final fallbackBaseUrl = ApiConfig.fallbackBaseUrl(request.baseUrl);
            if (fallbackBaseUrl != null) {
              try {
                final retryRequest = request.copyWith(
                  baseUrl: fallbackBaseUrl,
                  extra: <String, dynamic>{
                    ...request.extra,
                    'apiFailoverAttempted': true,
                  },
                );
                final response = await _dio.fetch<dynamic>(retryRequest);
                return handler.resolve(response);
              } on DioException {
                // Continue with the original error if both backends fail.
              }
            }
          }

          final shouldRefresh = error.response?.statusCode == 401 &&
              request.path != ApiEndpoints.login &&
              request.path != ApiEndpoints.refresh &&
              request.extra['retried'] != true;
          if (!shouldRefresh) return handler.next(error);

          try {
            await refreshSession();
            request.extra['retried'] = true;
            final token = await _storage.readAccessToken();
            if (token == null || token.isEmpty) {
              throw const ApiException('Session refresh failed');
            }
            request.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch<dynamic>(request);
            return handler.resolve(response);
          } on Object {
            await _storage.clear();
            _onUnauthorized?.call();
            return handler.next(error);
          }
        },
      ),
    );
  }

  bool _isTransportError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  final SecureStorageService _storage;
  final VoidCallback? _onUnauthorized;
  late final Dio _dio;
  Future<void>? _refreshFuture;

  Dio get dio => _dio;

  Future<bool> hasValidAccessToken() async {
    final token = await _storage.readAccessToken();
    return token != null &&
        token.isNotEmpty &&
        !_isTokenExpiredOrExpiring(token);
  }

  bool _isTokenExpiredOrExpiring(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return true;
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return true;
      final exp = decoded['exp'];
      if (exp is! num) return true;
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000);
      return DateTime.now().isAfter(
        expiresAt.subtract(const Duration(seconds: 30)),
      );
    } on Object {
      return true;
    }
  }

  Future<void> refreshSession() async {
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) return activeRefresh;
    final refresh = _performRefresh();
    _refreshFuture = refresh;
    try {
      await refresh;
    } finally {
      if (identical(_refreshFuture, refresh)) _refreshFuture = null;
    }
  }

  Future<void> _performRefresh() async {
    try {
      final refreshToken = await _storage.readRefreshToken();
      if (!kIsWeb && (refreshToken == null || refreshToken.isEmpty)) {
        throw const ApiException('No refresh token available');
      }
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: ApiConfig.baseUrl,
          headers: {
            'Accept': 'application/json',
            'X-Client-Platform': kIsWeb ? 'web' : 'native',
          },
        ),
      );
      configureHttpAdapter(refreshDio);
      final response = await refreshDio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: kIsWeb ? <String, dynamic>{} : {'refreshToken': refreshToken},
      );
      final data = response.data?['data'] as Map<String, dynamic>?;
      final access = data?['accessToken']?.toString();
      if (access == null) throw const ApiException('Session refresh failed');
      await _storage.writeTokens(
        accessToken: access,
        refreshToken: data?['refreshToken']?.toString(),
      );
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<Map<String, dynamic>> sendJson(
    String method,
    String path, {
    Object? data,
  }) async {
    try {
      final isLoginRequest = path == ApiEndpoints.login;
      final response = await _dio.request<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(
          method: method,
          // Render may need extra time to wake its backend on the first login.
          connectTimeout: isLoginRequest ? const Duration(seconds: 30) : null,
          receiveTimeout: isLoginRequest ? const Duration(seconds: 60) : null,
        ),
      );
      return response.data ?? <String, dynamic>{};
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
