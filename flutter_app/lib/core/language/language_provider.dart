import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languagePreferenceKey = 'app_language_code';

final appLanguageProvider =
    StateNotifierProvider<AppLanguageController, AppLanguage>((ref) {
  return AppLanguageController();
});

class AppLanguageController extends StateNotifier<AppLanguage> {
  AppLanguageController() : super(AppLanguageStore.current) {
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final language =
        AppLanguage.fromCode(prefs.getString(_languagePreferenceKey));
    AppLanguageStore.current = language;
    state = language;
  }

  Future<void> setLanguage(AppLanguage language) async {
    AppLanguageStore.current = language;
    state = language;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languagePreferenceKey, language.code);
  }
}
