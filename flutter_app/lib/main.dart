import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/language/language_provider.dart';
import 'package:matka_management/core/routing/app_router.dart';
import 'package:matka_management/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('hi'),
    initializeDateFormatting('mr'),
  ]);
  runApp(
    const ProviderScope(
      child: MatkaManagementApp(),
    ),
  );
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class MatkaManagementApp extends ConsumerWidget {
  const MatkaManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(appLanguageProvider);

    return MaterialApp.router(
      title: AppLocalizations.translate(language, 'Matka Entry System'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode
          .light, // Default to light mode for now based on UI screenshots
      locale: language.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      scrollBehavior: MyCustomScrollBehavior(),
      debugShowCheckedModeBanner: false,
    );
  }
}
