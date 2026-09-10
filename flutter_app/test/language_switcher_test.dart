import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/language/language_provider.dart';
import 'package:matka_management/core/language/language_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('changing language from the popup completes without an exception',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    AppLanguageStore.current = AppLanguage.english;
    addTearDown(() => AppLanguageStore.current = AppLanguage.english);

    await tester.pumpWidget(
      const ProviderScope(
        child: _LanguageSwitcherTestApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(LanguageSwitcher));
    await tester.pumpAndSettle();
    await tester.tap(find.text('HI'));
    await tester.pumpAndSettle();

    expect(find.text('locale:hi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _LanguageSwitcherTestApp extends ConsumerWidget {
  const _LanguageSwitcherTestApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(appLanguageProvider);
    return MaterialApp(
      locale: language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const LanguageSwitcher(),
              Text('locale:${Localizations.localeOf(context).languageCode}'),
            ],
          ),
        ),
      ),
    );
  }
}
