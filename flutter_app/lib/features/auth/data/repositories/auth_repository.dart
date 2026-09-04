import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/core/api/api_client.dart';
import 'package:matka_management/core/api/api_endpoints.dart';
import 'package:matka_management/core/storage/secure_storage_service.dart';
import 'package:matka_management/features/auth/data/models/access_status.dart';
import 'package:matka_management/features/auth/data/models/auth_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.read(apiClientProvider),
    ref.read(secureStorageProvider),
  );
});

class OtpRequestResult {
  const OtpRequestResult({this.developmentOtp, this.expiresInMinutes = 5});

  final String? developmentOtp;
  final int expiresInMinutes;

  factory OtpRequestResult.fromResponse(Map<String, dynamic> response) {
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return OtpRequestResult(
      developmentOtp: data['developmentOtp']?.toString(),
      expiresInMinutes:
          int.tryParse(data['expiresInMinutes']?.toString() ?? '') ?? 5,
    );
  }
}

class AuthRepository {
  const AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final SecureStorageService _storage;

  Future<bool> hasRefreshSession() => _storage.hasRefreshSession();

  Future<AuthUser> login({
    required String identifier,
    required String password,
  }) async {
    final deviceId = await _storage.installationId();
    final response = await _api.sendJson(
      'POST',
      ApiEndpoints.login,
      data: {
        'identifier': identifier,
        'password': password,
        'deviceId': deviceId,
      },
    );
    return _saveSession(response);
  }

  Future<OtpRequestResult> sendRegistrationOtp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _api.sendJson(
      'POST',
      ApiEndpoints.registerSendOtp,
      data: {
        'fullName': fullName.trim(),
        'email': email.trim().toLowerCase(),
        'phoneNumber': phoneNumber.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
    return OtpRequestResult.fromResponse(response);
  }

  Future<void> verifyRegistrationOtp({
    required String email,
    required String otp,
  }) async {
    await _api.sendJson(
      'POST',
      ApiEndpoints.registerVerifyOtp,
      data: {'email': email.trim().toLowerCase(), 'otp': otp.trim()},
    );
  }

  Future<AuthUser> refresh() async {
    try {
      await _api.refreshSession();
      return me();
    } on Object {
      await _storage.clear();
      rethrow;
    }
  }

  Future<AuthUser> me() async {
    final response = await _api.getJson(ApiEndpoints.me);
    final data = response['data'] as Map<String, dynamic>;
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<AccessStatus> accessStatus() async {
    final response = await _api.getJson(ApiEndpoints.subscriptionStatus);
    final data = response['data'] as Map<String, dynamic>? ?? const {};
    return AccessStatus.fromJson(data);
  }

  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    try {
      await _api.sendJson(
        'POST',
        ApiEndpoints.logout,
        data: refreshToken == null
            ? <String, dynamic>{}
            : {
                'refreshToken': refreshToken,
              },
      );
    } catch (_) {
      // Ignore API errors during logout (e.g. token already expired)
    } finally {
      await _storage.clear();
    }
  }

  Future<OtpRequestResult> forgotPassword(String email) async {
    final response = await _api.sendJson(
      'POST',
      ApiEndpoints.forgotPassword,
      data: {'email': email.trim().toLowerCase()},
    );
    return OtpRequestResult.fromResponse(response);
  }

  Future<void> verifyForgotPasswordOtp({
    required String email,
    required String otp,
  }) async {
    await _api.sendJson(
      'POST',
      ApiEndpoints.forgotPasswordVerifyOtp,
      data: {'email': email.trim().toLowerCase(), 'otp': otp.trim()},
    );
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String password,
    required String confirmPassword,
  }) async {
    await _api.sendJson(
      'POST',
      ApiEndpoints.resetPassword,
      data: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
        'password': password,
        'confirmPassword': confirmPassword,
      },
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String password,
  }) async {
    await _api.sendJson(
      'POST',
      ApiEndpoints.changePassword,
      data: {'currentPassword': currentPassword, 'password': password},
    );
    await _storage.clear();
  }

  Future<AuthUser> _saveSession(Map<String, dynamic> response) async {
    final data = response['data'] as Map<String, dynamic>;
    await _storage.writeTokens(
      accessToken: data['accessToken'].toString(),
      refreshToken: data['refreshToken']?.toString(),
    );
    return AuthUser.fromJson(data['user'] as Map<String, dynamic>);
  }
}
