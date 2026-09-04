import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/language/language_switcher.dart';
import 'package:matka_management/shared/widgets/app_sidebar.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 700;
    final isTablet = width >= 700 && width < 1100;

    if (isMobile) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFD),
        appBar: AppBar(
          backgroundColor: const Color(0xFF064DB5),
          foregroundColor: Colors.white,
          title: Text(
            context.tr(_titleForPath(context)),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: context.tr('Save'),
              icon: const Icon(Icons.save_outlined),
              onPressed: () {},
            ),
            const LanguageSwitcher(compact: true),
          ],
        ),
        drawer: const AppNavigationDrawer(),
        body: child,
        bottomNavigationBar: const MobileBottomNavigation(),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Row(
        children: [
          AppSidebar(collapsed: isTablet),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }

  String _titleForPath(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    for (final item in appNavigationItems) {
      if (!item.isLogout &&
          (path == item.path || path.startsWith('${item.path}/'))) {
        return item.label;
      }
    }
    return 'Matka Entry System';
  }
}
