import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _renderBaseUrl = 'https://gameskmrmowbmos-jito.onrender.com/api';
  static const _localPort = 5003;

  static String get baseUrl {
    return baseUrls.first;
  }

  static List<String> get baseUrls {
    if (_definedBaseUrl.isNotEmpty) return [_normalize(_definedBaseUrl)];

    return <String>[_renderBaseUrl, _localBaseUrl];
  }

  static String? fallbackBaseUrl(String currentBaseUrl) {
    final currentIndex = baseUrls.indexOf(currentBaseUrl);
    if (currentIndex == -1 || currentIndex + 1 >= baseUrls.length) {
      return null;
    }
    return baseUrls[currentIndex + 1];
  }

  static String get _localBaseUrl {
    if (kIsWeb) return 'http://localhost:$_localPort/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_localPort/api';
    }
    return 'http://localhost:$_localPort/api';
  }

  static String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
