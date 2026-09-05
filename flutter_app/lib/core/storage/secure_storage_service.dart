import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

class SecureStorageService {
  SecureStorageService();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _installationKey = 'installation_id';
  static const _webSessionHintKey = 'web_auth_session_hint';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  String? _webAccessToken;
  String? _webInstallationId;

  Future<String?> readAccessToken() async {
    if (kIsWeb) return _webAccessToken;
    return _storage.read(key: _accessKey);
  }

  Future<String?> readRefreshToken() async {
    if (kIsWeb) return null;
    return _storage.read(key: _refreshKey);
  }

  Future<bool> hasRefreshSession() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_webSessionHintKey) ?? false;
    }
    final refreshToken = await _storage.read(key: _refreshKey);
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    if (kIsWeb) {
      _webAccessToken = accessToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_webSessionHintKey, true);
      return;
    }
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  Future<String> installationId() async {
    if (kIsWeb) {
      _webInstallationId ??= _newInstallationId();
      return _webInstallationId!;
    }
    final existing = await _storage.read(key: _installationKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _newInstallationId();
    await _storage.write(key: _installationKey, value: created);
    return created;
  }

  String _newInstallationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    return bytes.map(hex).join();
  }

  Future<void> clear() async {
    _webAccessToken = null;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_webSessionHintKey);
      return;
    }
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
