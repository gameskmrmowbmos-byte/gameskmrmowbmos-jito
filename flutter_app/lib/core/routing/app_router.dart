import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/features/auth/presentation/login_page.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:matka_management/features/auth/presentation/screens/register_screen.dart';
import 'package:matka_management/features/auth/presentation/screens/splash_screen.dart';
import 'package:matka_management/features/entries/presentation/entries_page.dart';
import 'package:matka_management/features/new_entry/presentation/new_entry_page.dart';
import 'package:matka_management/features/receipt_search/presentation/search_receipt_page.dart';
import 'package:matka_management/features/settings/presentation/settings_page.dart';
import 'package:matka_management/features/share_records/presentation/share_records_page.dart';
import 'package:matka_management/layout/main_layout.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authNotifier = ValueNotifier<AuthStatus>(ref.read(authProvider).status);

  ref
    ..listen<AuthState>(authProvider, (_, next) {
      authNotifier.value = next.status;
    })
    ..onDispose(authNotifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isSplashRoute = state.matchedLocation == '/splash';
      final publicAuthRoute = {
        '/login',
        '/register',
        '/forgot-password',
      }.contains(state.matchedLocation);

      if (auth.status == AuthStatus.initializing) {
        if (isSplashRoute) return null;
        final from = Uri.encodeComponent(state.uri.toString());
        return '/splash?from=$from';
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return publicAuthRoute ? null : '/login';
      }
      if (isSplashRoute) {
        final from = state.uri.queryParameters['from'];
        if (from != null && from.startsWith('/')) return from;
        return '/new-entry';
      }
      if (publicAuthRoute) return '/new-entry';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(
            path: '/new-entry',
            builder: (context, state) => const NewEntryPage(),
          ),
          GoRoute(
            path: '/entries',
            builder: (context, state) => const EntriesPage(),
          ),
          GoRoute(
            path: '/search',
            builder: (context, state) => const SearchReceiptPage(),
          ),
          GoRoute(
            path: '/share-records',
            builder: (context, state) => const ShareRecordsPage(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsPage(),
          ),
        ],
      ),
    ],
  );
});
