import 'package:flutter/widgets.dart';

/// Layout sizes, following Material 3 window size classes.
///
/// The personas drive these: agents and employees are on phones (compact), the
/// director, HR and finance are on laptops (expanded). Both get every feature —
/// only the primary action and information density change.
enum WindowSize {
  /// Phone. Bottom navigation, single pane, thumb-reachable primary action.
  compact,

  /// Tablet or a small desktop window. Navigation rail, two panes.
  medium,

  /// Desktop. Permanent drawer, three panes, real data tables.
  expanded,

  /// Large desktop. As expanded, with wider dashboard grids.
  large;

  bool get isCompact => this == WindowSize.compact;
  bool get isMedium => this == WindowSize.medium;

  /// True where a list and its detail can sit side by side.
  bool get hasSidePanel => index >= WindowSize.medium.index;

  /// True where a third inspector pane fits.
  bool get hasInspector => index >= WindowSize.expanded.index;

  /// Dashboard grid columns. The director's KPI row is the main consumer.
  int get dashboardColumns => switch (this) {
    WindowSize.compact => 1,
    WindowSize.medium => 2,
    WindowSize.expanded => 4,
    WindowSize.large => 4,
  };
}

class Breakpoints {
  const Breakpoints._();

  static const double medium = 600;
  static const double expanded = 1024;
  static const double large = 1440;

  static WindowSize of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  static WindowSize fromWidth(double width) {
    if (width >= large) return WindowSize.large;
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }
}

/// Convenience accessors so widgets read `context.windowSize` rather than
/// recomputing the breakpoint inline each time.
extension ResponsiveContext on BuildContext {
  WindowSize get windowSize => Breakpoints.of(this);
  bool get isCompact => windowSize.isCompact;
  bool get hasSidePanel => windowSize.hasSidePanel;
}
