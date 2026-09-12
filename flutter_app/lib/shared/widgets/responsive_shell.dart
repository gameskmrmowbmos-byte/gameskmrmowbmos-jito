import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/core/constants/app_constants.dart';
import 'package:matka_management/core/language/app_localizations.dart';
import 'package:matka_management/core/widgets/responsive.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/new_entry/presentation/new_entry_draft_provider.dart';

class _Destination {
  const _Destination(
    this.label,
    this.path,
    this.icon, {
    this.adminOnly = false,
  });

  final String label;
  final String path;
  final IconData icon;
  final bool adminOnly;
}

const _destinations = [
  _Destination('Dashboard', '/dashboard', Icons.dashboard_outlined),
  _Destination('Entries', '/entries', Icons.receipt_long_outlined),
  _Destination('Markets', '/markets', Icons.storefront_outlined),
  _Destination('Results', '/results', Icons.verified_outlined),
  _Destination('Operators', '/users', Icons.group_outlined, adminOnly: true),
  _Destination(
    'Audit logs',
    '/audit-logs',
    Icons.history_outlined,
    adminOnly: true,
  ),
];

class ResponsiveShell extends ConsumerWidget {
  const ResponsiveShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final destinations = _destinations
        .where((item) => !item.adminOnly || user?.isAdmin == true)
        .toList();
    final currentPath = GoRouterState.of(context).uri.path;
    final selectedIndex = destinations.indexWhere(
      (item) =>
          currentPath == item.path || currentPath.startsWith('${item.path}/'),
    );
    final effectiveIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final screenClass = Responsive.classOf(context);

    void navigate(int index) => context.go(destinations[index].path);

    if (screenClass == ScreenClass.desktop) {
      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: 250,
              child: _Sidebar(
                destinations: destinations,
                selectedIndex: effectiveIndex,
                onSelected: navigate,
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _TopBar(userName: user?.fullName ?? ''),
                  const Divider(height: 1),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (screenClass == ScreenClass.tablet) {
      return Scaffold(
        appBar: AppBar(
          title: Text(context.tr(AppConstants.applicationName)),
          actions: const [_ProfileMenu()],
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: effectiveIndex,
              onDestinationSelected: navigate,
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map(
                    (item) => NavigationRailDestination(
                      icon: Icon(item.icon),
                      label: Text(context.tr(item.label)),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    final primaryDestinations = destinations.take(5).toList();
    final mobileIndex = primaryDestinations.indexWhere(
      (item) =>
          currentPath == item.path || currentPath.startsWith('${item.path}/'),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(destinations[effectiveIndex].label),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [_ProfileMenu()],
      ),
      drawer: NavigationDrawer(
        selectedIndex: effectiveIndex,
        onDestinationSelected: (index) {
          Navigator.of(context).pop();
          navigate(index);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 16, 12),
            child: Text(
              context.tr(AppConstants.applicationName),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          ...destinations.map(
            (item) => NavigationDrawerDestination(
              icon: Icon(item.icon),
              label: Text(context.tr(item.label)),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIndex < 0 ? 0 : mobileIndex,
        onDestinationSelected: (index) =>
            context.go(primaryDestinations[index].path),
        destinations: primaryDestinations
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                label: context.tr(item.label),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: const Color(0xFF0F172A),
      child: Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: theme.colorScheme.primary,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 16, 22),
                child: Row(
                  children: [
                    const Icon(Icons.fact_check_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('Matka Management - Demo'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: destinations.length,
                  itemBuilder: (context, index) {
                    final item = destinations[index];
                    final isSelected = selectedIndex == index;
                    final theme = Theme.of(context);
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      selectedColor: theme.colorScheme.primary,
                      leading: Icon(item.icon),
                      title: Text(
                        context.tr(item.label),
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      onTap: () => onSelected(index),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.tr('Record management only\nNo real-money features'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.userName});

  final String userName;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Expanded(
              child: Text(
                context.tr(AppConstants.legalNotice),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 16),
            Text(userName),
            const _ProfileMenu(),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenu extends ConsumerWidget {
  const _ProfileMenu();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: context.tr('Account menu'),
      icon: const CircleAvatar(child: Icon(Icons.person_outline)),
      onSelected: (value) async {
        if (value == 'profile') context.go('/profile');
        if (value == 'password') context.go('/change-password');
        if (value == 'logout') {
          ref.read(newEntryDraftProvider.notifier).clearActive();
          await ref.read(authProvider.notifier).logout();
          if (context.mounted) context.go('/login');
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(value: 'profile', child: Text(context.tr('Profile'))),
        PopupMenuItem(
          value: 'password',
          child: Text(context.tr('Change password')),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'logout', child: Text(context.tr('Sign out'))),
      ],
    );
  }
}
