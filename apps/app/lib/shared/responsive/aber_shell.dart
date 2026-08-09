import 'package:flutter/material.dart';

import 'breakpoints.dart';

/// A destination in the app's primary navigation.
@immutable
class ShellDestination {
  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}

/// The single navigation shell for all five platforms.
///
/// One widget rather than separate mobile and desktop trees: the features are
/// identical across form factors, only the chrome differs, and two trees would
/// drift apart the first time someone fixed a bug in only one of them.
///
///   compact  -> bottom NavigationBar
///   medium   -> collapsed NavigationRail
///   expanded -> NavigationRail with labels
///   large    -> permanent extended rail
class AberShell extends StatelessWidget {
  const AberShell({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.child,
    this.title,
    this.actions,
    this.floatingActionButton,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    return switch (size) {
      WindowSize.compact => _buildCompact(context),
      _ => _buildWithRail(context, size),
    };
  }

  Widget _buildCompact(BuildContext context) {
    // More than five bottom items becomes unusable on a phone; the overflow
    // moves into a "More" sheet once the app has that many modules.
    final visible = destinations.take(5).toList();
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      body: SafeArea(child: child),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex.clamp(0, visible.length - 1),
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final d in visible)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }

  Widget _buildWithRail(BuildContext context, WindowSize size) {
    final extended = size == WindowSize.large;
    return Scaffold(
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child: Row(
          children: [
            NavigationRail(
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: selectedIndex.clamp(0, destinations.length - 1),
              onDestinationSelected: onDestinationSelected,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// List-and-detail layout that collapses to a single pane on a phone.
///
/// On compact widths the caller pushes a route for the detail instead; this
/// widget only renders the split when there is room for it.
class AdaptiveListDetail extends StatelessWidget {
  const AdaptiveListDetail({
    super.key,
    required this.list,
    this.detail,
    this.inspector,
    this.listFlex = 2,
    this.detailFlex = 3,
  });

  final Widget list;
  final Widget? detail;
  final Widget? inspector;
  final int listFlex;
  final int detailFlex;

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;

    if (!size.hasSidePanel) return list;

    return Row(
      children: [
        Expanded(flex: listFlex, child: list),
        const VerticalDivider(width: 1),
        Expanded(flex: detailFlex, child: detail ?? const _NothingSelected()),
        if (inspector != null && size.hasInspector) ...[
          const VerticalDivider(width: 1),
          Expanded(child: inspector!),
        ],
      ],
    );
  }
}

class _NothingSelected extends StatelessWidget {
  const _NothingSelected();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'Select an item to see its details',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
