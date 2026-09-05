import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_definedBaseUrl.isNotEmpty) return _normalize(_definedBaseUrl);
    if (kIsWeb) return 'http://localhost:5002/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5002/api';
    }
    return 'http://localhost:5002/api';
  }

  static String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
