import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<SecureStorageService>(
  (ref) => SecureStorageService(),
);

class SecureStorageService {
  SecureStorageService();

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _installationKey = 'installation_id';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  Future<bool> hasRefreshSession() async {
    final refreshToken = await readRefreshToken();
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    if (refreshToken != null) {
      await _storage.write(key: _refreshKey, value: refreshToken);
    }
  }

  Future<String> installationId() async {
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
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
