import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/settings/presentation/system_status_page.dart';
import '../shared/responsive/aber_shell.dart';

/// Application routes.
///
/// `StatefulShellRoute.indexedStack` keeps each module's navigation stack alive
/// when switching tabs, so an agent part-way through a lead form does not lose
/// it by glancing at their attendance.
///
/// Deep-link paths double as push-notification targets (`aber://deal/{id}`), so
/// route names are treated as a stable contract, not an implementation detail.

const _destinations = <ShellDestination>[
  ShellDestination(
    label: 'Home',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
    route: '/home',
  ),
  ShellDestination(
    label: 'Properties',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment,
    route: '/properties',
  ),
  ShellDestination(
    label: 'Leads',
    icon: Icons.people_outline,
    selectedIcon: Icons.people,
    route: '/leads',
  ),
  ShellDestination(
    label: 'Attendance',
    icon: Icons.schedule_outlined,
    selectedIcon: Icons.schedule,
    route: '/attendance',
  ),
  ShellDestination(
    label: 'Status',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    route: '/status',
  ),
];

GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/status',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AberShell(
          destinations: _destinations,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          title: _destinations[navigationShell.currentIndex].label,
          child: navigationShell,
        ),
        branches: [
          _branch(
            '/home',
            const _ComingSoon(module: 'Director dashboard', milestone: 'M7'),
          ),
          _branch(
            '/properties',
            const _ComingSoon(module: 'Properties', milestone: 'M4'),
          ),
          _branch(
            '/leads',
            const _ComingSoon(module: 'Leads & deals', milestone: 'M5'),
          ),
          _branch(
            '/attendance',
            const _ComingSoon(module: 'Attendance', milestone: 'M3'),
          ),
          _branch('/status', const SystemStatusPage()),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, Widget child) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, __) => child)],
);

/// Placeholder for modules landing in later milestones. Naming the milestone
/// keeps a demo honest — nobody mistakes an empty tab for a broken one.
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.module, required this.milestone});

  final String module;
  final String milestone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(module, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Arriving in milestone $milestone',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
