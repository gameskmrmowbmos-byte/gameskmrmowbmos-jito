import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

class SecureStorageService {
  SecureStorageService();

  static const _accessKey = 'access_token';
  static const _installationKey = 'installation_id';
  static const _sessionHintKey = 'web_auth_session_hint';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> readAccessToken() async =>
      (await _prefs).getString(_accessKey);

  Future<String?> readRefreshToken() async => null;

  Future<bool> hasRefreshSession() async {
    return (await _prefs).getBool(_sessionHintKey) ?? false;
  }

  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    final prefs = await _prefs;
    await prefs.setString(_accessKey, accessToken);
    await prefs.setBool(_sessionHintKey, true);
  }

  Future<String> installationId() async {
    final prefs = await _prefs;
    final existing = prefs.getString(_installationKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final created = bytes.map(hex).join();
    await prefs.setString(_installationKey, created);
    return created;
  }

  Future<void> clear() async {
    final prefs = await _prefs;
    await prefs.remove(_accessKey);
    await prefs.remove(_sessionHintKey);
  }
}
