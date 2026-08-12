import 'dart:ui';

import 'package:flutter/foundation.dart';
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
    this.compactTheme,
    this.useNativeCompactChrome = false,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  /// The product's own theme, e.g. `EstateOpsTheme`, applied at every width.
  ///
  /// It used to be phone-only, with desktop falling through to the ambient
  /// teal M3 theme. That gave the same product two identities depending on how
  /// wide the window was, and the desktop one looked like a different app.
  /// Null keeps the ambient theme, so callers that don't opt in are unaffected.
  final ThemeData? compactTheme;

  /// Swaps the default Material [NavigationBar] for chrome that matches the
  /// running platform (an iOS-style tab bar, an Android-style pill nav) —
  /// used by the Estate Ops shell. Defaults to false so existing callers and
  /// tests keep seeing a plain [NavigationBar].
  final bool useNativeCompactChrome;

  @override
  Widget build(BuildContext context) {
    final size = context.windowSize;
    final scaffold = switch (size) {
      WindowSize.compact => _buildCompact(context),
      _ => _buildWithRail(context, size),
    };

    if (compactTheme == null) return scaffold;
    return Theme(data: compactTheme!, child: scaffold);
  }

  Widget _buildCompact(BuildContext context) {
    // More than five bottom items becomes unusable on a phone; the overflow
    // moves into a "More" sheet once the app has that many modules.
    final visible = destinations.take(5).toList();
    return Scaffold(
      // Only the glass bar is worth showing content through. The native tab
      // bars are opaque, so extending the body under one just buries the last
      // row of every scrolling screen somewhere the user cannot tap it.
      extendBody: !useNativeCompactChrome,
      appBar: title == null
          ? null
          : AppBar(title: Text(title!), actions: actions),
      body: SafeArea(child: child),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: useNativeCompactChrome
          ? _NativeTabBar(
              destinations: visible,
              selectedIndex: selectedIndex.clamp(0, visible.length - 1),
              onDestinationSelected: onDestinationSelected,
            )
          : _GlassBottomNavigationBar(
              child: NavigationBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
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
            Expanded(child: ReadableWidth(child: child)),
          ],
        ),
      ),
    );
  }
}

/// Caps content at a readable measure and centres it.
///
/// These screens are lists of rows: a title on the left, a status on the right.
/// Stretched to a 2000px window that becomes a title, an acre of nothing, and a
/// badge on the far edge — the eye cannot connect the two, and it looks like a
/// bug rather than a layout. Every well-built wide-screen app caps the measure
/// somewhere; this one does it here, once, so no individual screen has to
/// remember to.
///
/// [maxWidth] is deliberately generous. Narrower reads better for prose, but
/// these rows carry a label *and* a trailing value, and squeezing them starts
/// wrapping the labels.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = 940});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Picks iOS tab-bar or Android pill-nav chrome by the running platform —
/// both frames share the same [ShellDestination]s, only the look differs.
class _NativeTabBar extends StatelessWidget {
  const _NativeTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return defaultTargetPlatform == TargetPlatform.iOS
        ? _IOSTabBar(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          )
        : _AndroidPillNav(
            destinations: destinations,
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
          );
  }
}

class _IOSTabBar extends StatelessWidget {
  const _IOSTabBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(4, 10, 4, bottomInset),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          for (final (index, d) in destinations.indexed)
            Expanded(
              child: _TabBarItem(
                label: d.label,
                active: index == selectedIndex,
                onTap: () => onDestinationSelected(index),
                indicator: (active) => Container(
                  width: 22,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? scheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                labelStyle: (active) => TextStyle(
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AndroidPillNav extends StatelessWidget {
  const _AndroidPillNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final List<ShellDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(4, 12, 4, bottomInset),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          for (final (index, d) in destinations.indexed)
            Expanded(
              child: _TabBarItem(
                label: d.label,
                active: index == selectedIndex,
                onTap: () => onDestinationSelected(index),
                // Material 3 seats the icon inside the pill, and swaps to the
                // filled variant when the destination is selected.
                indicator: (active) => Container(
                  width: 56,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    active ? d.selectedIcon : d.icon,
                    size: 18,
                    color: active ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                ),
                labelStyle: (active) => TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? scheme.onSurface : scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabBarItem extends StatelessWidget {
  const _TabBarItem({
    required this.label,
    required this.active,
    required this.onTap,
    required this.indicator,
    required this.labelStyle,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Widget Function(bool active) indicator;
  final TextStyle Function(bool active) labelStyle;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          indicator(active),
          const SizedBox(height: 5),
          Text(label, style: labelStyle(active)),
        ],
      ),
    );
  }
}

class _GlassBottomNavigationBar extends StatelessWidget {
  const _GlassBottomNavigationBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: isDark ? 0.72 : 0.66),
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(
                  alpha: isDark ? 0.18 : 0.42,
                ),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.24 : 0.10),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: child,
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
