import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/domain/auth_user.dart';
import '../features/auth/presentation/sign_in_page.dart';
import '../features/auth/presentation/sign_up_page.dart';
import '../features/auth/presentation/starting_page.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/estate_ops/presentation/deal_detail_page.dart';
import '../features/estate_ops/presentation/deals_page.dart';
import '../features/estate_ops/presentation/inventory_page.dart';
import '../features/estate_ops/presentation/module_detail_page.dart';
import '../features/estate_ops/presentation/more_page.dart';
import '../features/estate_ops/presentation/person_detail_page.dart';
import '../features/estate_ops/presentation/profile_page.dart';
import '../features/estate_ops/presentation/property_detail_page.dart';
import '../features/estate_ops/presentation/team_page.dart';
import '../features/estate_ops/presentation/today_page.dart';
import '../features/estate_ops/presentation/widgets/estate_widgets.dart';
import '../features/settings/presentation/system_status_page.dart';
import '../shared/responsive/aber_shell.dart';
import '../shared/theme/estate_ops_theme.dart';

/// Application routes.
///
/// `StatefulShellRoute.indexedStack` keeps each module's navigation stack alive
/// when switching tabs, so an agent part-way through a lead form does not lose
/// it by glancing at their attendance.
///
/// Deep-link paths double as push-notification targets (`aber://deal/{id}`), so
/// route names are treated as a stable contract, not an implementation detail.
///
/// The five tabs mirror the Estate Ops staff-app design: Today, Inventory,
/// Deals, Team and More. Each tab renders its own inline title, so the shell
/// carries no separate app-bar title on any window size.

const _destinations = <ShellDestination>[
  ShellDestination(
    label: 'Today',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
    route: '/today',
  ),
  ShellDestination(
    label: 'Inventory',
    icon: Icons.apartment_outlined,
    selectedIcon: Icons.apartment,
    route: '/inventory',
  ),
  ShellDestination(
    label: 'Deals',
    icon: Icons.handshake_outlined,
    selectedIcon: Icons.handshake,
    route: '/deals',
  ),
  ShellDestination(
    label: 'Team',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
    route: '/team',
  ),
  ShellDestination(
    label: 'More',
    icon: Icons.more_horiz_outlined,
    selectedIcon: Icons.more_horiz,
    route: '/more',
  ),
];

/// Paths reachable without a session. Everything else redirects to sign-in.
const _publicPaths = {'/sign-in', '/sign-up'};

/// Builds the app router.
///
/// [initialLocation] exists so tests (and, later, a cold start from a push
/// notification) can open straight onto a deep link instead of always entering
/// through `/today`.
///
/// [auth] installs the sign-in gate. It is optional so widget tests can drive a
/// screen directly without signing in first — passing it is what the real app
/// does, and the gate is only as good as the server behind it either way:
/// hiding a route on the client is navigation, not authorisation.
GoRouter createRouter({
  String initialLocation = '/today',
  AuthController? auth,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    // Re-runs the redirect below the moment someone signs in or out.
    refreshListenable: auth,
    redirect: auth == null ? null : (context, state) => _guard(auth, state),
    routes: [
      GoRoute(path: '/starting', builder: (_, __) => const StartingPage()),
      GoRoute(
        path: '/sign-in',
        builder: (_, __) => const EstateOpsCompactTheme(child: SignInPage()),
      ),
      GoRoute(
        path: '/sign-up',
        builder: (_, __) => const EstateOpsCompactTheme(child: SignUpPage()),
      ),
      // Outside the shell on purpose: the header avatar opens the profile from
      // whichever tab the user is on, and a branch route would switch tabs
      // under them. This covers the shell and pops back to where they were.
      GoRoute(
        path: '/profile',
        builder: (_, __) =>
            const EstateOpsCompactTheme(child: ProfilePage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AberShell(
          destinations: _destinations,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          compactTheme: EstateOpsTheme.dark(),
          useNativeCompactChrome: true,
          child: navigationShell,
        ),
        branches: [
          _branch('/today', const TodayPage()),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                builder: (_, __) => const InventoryPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) => PropertyDetailPage(
                      listingId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/deals',
                builder: (_, __) => const DealsPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        DealDetailPage(dealId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/team',
                builder: (_, __) => const TeamPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (_, state) =>
                        PersonDetailPage(personId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                builder: (_, __) => const MorePage(),
                routes: [
                  GoRoute(
                    path: ':key',
                    builder: (_, state) {
                      final key = state.pathParameters['key']!;
                      return key == 'status'
                          ? Scaffold(
                              appBar: const OpsDetailAppBar(
                                title: 'System status',
                              ),
                              body: const SystemStatusPage(),
                            )
                          : ModuleDetailPage(moduleKey: key);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

StatefulShellBranch _branch(String path, Widget child) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, __) => child)],
);

/// Decides where a navigation is allowed to land, given the session.
///
/// Returning null means "leave it alone", which is the common case — a
/// redirect that fires on every navigation is a redirect loop waiting to
/// happen, so each branch here only diverts when the destination genuinely
/// contradicts the session state.
String? _guard(AuthController auth, GoRouterState state) {
  final location = state.matchedLocation;

  return switch (auth.status) {
    // Still reading storage: hold everyone on the splash rather than guess.
    AuthStatus.unknown => location == '/starting' ? null : '/starting',
    AuthStatus.signedOut =>
      _publicPaths.contains(location) ? null : '/sign-in',
    AuthStatus.signedIn =>
      location == '/starting' || _publicPaths.contains(location)
          ? '/today'
          : null,
  };
}
