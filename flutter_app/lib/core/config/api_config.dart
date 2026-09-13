import 'package:flutter/foundation.dart';

class ApiConfig {
  ApiConfig._();

  static const _definedBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _renderBaseUrl =
      'https://gameskmrmowbmos-jito.onrender.com/api';

  static String get baseUrl {
    return baseUrls.first;
  }

  static List<String> get baseUrls {
    if (_definedBaseUrl.isNotEmpty) return [_normalize(_definedBaseUrl)];

    return kReleaseMode
        ? <String>[_renderBaseUrl, _localBaseUrl]
        : <String>[_localBaseUrl, _renderBaseUrl];
  }

  static String? fallbackBaseUrl(String currentBaseUrl) {
    final currentIndex = baseUrls.indexOf(currentBaseUrl);
    if (currentIndex == -1 || currentIndex + 1 >= baseUrls.length) {
      return null;
    }
    return baseUrls[currentIndex + 1];
  }

  static String get _localBaseUrl {
    if (kIsWeb) return 'http://localhost:5002/api';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5002/api';
    }
    return 'http://localhost:5002/api';
  }

  static String _normalize(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
