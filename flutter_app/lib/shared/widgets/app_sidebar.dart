import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:matka_management/features/auth/presentation/providers/auth_provider.dart';
import 'package:matka_management/features/new_entry/presentation/new_entry_draft_provider.dart';

const _navBlue = Color(0xFF064DB5);
const _navRed = Color(0xFFF20D16);
const _navDarkTop = Color(0xFF05182B);
const _navDarkBottom = Color(0xFF02233A);

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.shortLabel,
    required this.path,
    required this.icon,
    this.isLogout = false,
  });

  final String label;
  final String shortLabel;
  final String path;
  final IconData icon;
  final bool isLogout;
}

const appNavigationItems = [
  AppNavigationItem(
    label: 'New Entry',
    shortLabel: 'Entry',
    path: '/new-entry',
    icon: Icons.edit_outlined,
  ),
  AppNavigationItem(
    label: 'Share Records PNG',
    shortLabel: 'Share PNG',
    path: '/share-records',
    icon: Icons.image_outlined,
  ),
  AppNavigationItem(
    label: 'Entries',
    shortLabel: 'Entries',
    path: '/entries',
    icon: Icons.receipt_long_outlined,
  ),
  AppNavigationItem(
    label: 'Search Parchi',
    shortLabel: 'Search',
    path: '/search',
    icon: Icons.search,
  ),
  AppNavigationItem(
    label: 'Logout',
    shortLabel: 'Logout',
    path: '/login',
    icon: Icons.power_settings_new,
    isLogout: true,
  ),
];

class AppSidebar extends StatelessWidget {
  const AppSidebar({this.collapsed = false, super.key});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final width = collapsed ? 76.0 : 230.0;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_navDarkTop, _navDarkBottom],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: collapsed ? 18 : 30),
            _SidebarLogo(collapsed: collapsed),
            SizedBox(height: collapsed ? 26 : 32),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: collapsed ? 8 : 10),
                children: [
                  for (var index = 0;
                      index < appNavigationItems.length;
                      index++)
                    if (!appNavigationItems[index].isLogout)
                      _SidebarItem(
                        item: appNavigationItems[index],
                        index: index + 1,
                        collapsed: collapsed,
                        isSelected:
                            _isSelected(location, appNavigationItems[index]),
                      ),
                ],
              ),
            ),
            _SidebarItem(
              item: appNavigationItems.last,
              index: appNavigationItems.length,
              collapsed: collapsed,
              isSelected: false,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_navDarkTop, _navDarkBottom],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              const _SidebarLogo(collapsed: false),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    for (var index = 0;
                        index < appNavigationItems.length;
                        index++)
                      _SidebarItem(
                        item: appNavigationItems[index],
                        index: index + 1,
                        collapsed: false,
                        isSelected:
                            _isSelected(location, appNavigationItems[index]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileBottomNavigation extends StatelessWidget {
  const MobileBottomNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final items = appNavigationItems.where((item) => !item.isLogout).toList();
    final selected = items.indexWhere((item) => _isSelected(location, item));

    return NavigationBar(
      height: 66,
      selectedIndex: selected < 0 ? 0 : selected,
      onDestinationSelected: (index) => context.go(items[index].path),
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.icon, color: _navBlue),
            label: item.shortLabel,
          ),
      ],
    );
  }
}

class _SidebarLogo extends StatelessWidget {
  const _SidebarLogo({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return const Icon(Icons.workspace_premium, color: Colors.amber, size: 30);
    }
    return Column(
      children: const [
        Icon(Icons.workspace_premium, color: Colors.amber, size: 28),
        SizedBox(height: 4),
        Text(
          'MATKA',
          style: TextStyle(
            color: Colors.amber,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'ENTRY SYSTEM',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends ConsumerWidget {
  const _SidebarItem({
    required this.item,
    required this.index,
    required this.collapsed,
    required this.isSelected,
  });

  final AppNavigationItem item;
  final int index;
  final bool collapsed;
  final bool isSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = item.isLogout
        ? _navRed
        : isSelected
            ? Colors.white
            : Colors.white.withValues(alpha: 0.86);
    final background = isSelected ? _navBlue : Colors.transparent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: item.label,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(5),
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () async {
              if (item.isLogout) {
                ref.read(newEntryDraftProvider.notifier).clearActive();
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/login');
              } else {
                context.go(item.path);
              }
            },
            child: SizedBox(
              height: 46,
              child: collapsed
                  ? Icon(item.icon, color: color, size: 22)
                  : Row(
                      children: [
                        const SizedBox(width: 14),
                        Icon(item.icon, color: color, size: 21),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$index. ${item.label}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSelected(String location, AppNavigationItem item) {
  if (item.isLogout) return false;
  return location == item.path || location.startsWith('${item.path}/');
}
