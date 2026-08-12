import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/theme/estate_ops_extras.dart';
import '../../data/estate_ops_data.dart';

/// Small, theme-driven building blocks shared by every Estate Ops screen.
///
/// Everything reads [ColorScheme] / [EstateOpsExtras] rather than literal hex
/// so the same widgets render as the dark staff-app look on a phone and as
/// the ambient light/dark M3 look behind the navigation rail on larger
/// screens.

/// Confirms an action that has no backend behind it yet. Every Estate Ops
/// detail action routes through here so the placeholder feedback stays
/// consistent, and so there is a single place to delete once the real calls
/// land.
void showOpsSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Confirms a state change through the hand as well as the eye.
///
/// The agents using this are on a phone, one-handed, often outdoors and
/// half-watching where they are walking — a clock-in that only confirms
/// visually is one they check twice. Kept behind a helper so every state
/// change in the app uses the same weight rather than each screen picking one.
void opsTick() => HapticFeedback.selectionClick();

/// "9 Aug" — the shape the seeded visit histories use.
String opsDayLabel(DateTime at) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${at.day} ${months[at.month - 1]}';
}

/// "Today, 9:20 am" — the shape the seeded timelines already use, so a record
/// the agent just made does not look like a different kind of thing to the
/// ones above it.
String opsTimestamp([DateTime? at]) {
  final now = at ?? DateTime.now();
  final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
  final minute = now.minute.toString().padLeft(2, '0');
  return 'Today, $hour:$minute ${now.hour < 12 ? 'am' : 'pm'}';
}

/// The smallest a control may be and still be reliably hit with a thumb.
///
/// Several of this design's controls are drawn smaller than this — a 26dp
/// "Call" pill, a 34dp back chevron. Rather than fatten them and lose the look,
/// [TapTarget] keeps the paint and grows only the touchable box, which is what
/// Material's own `MaterialTapTargetSize.padded` does for its buttons. The
/// ripple ends up slightly larger than the thing it surrounds, exactly as it
/// does on an [IconButton].
const double kMinTapTarget = 44;

/// Centres [child] in a box at least [kMinTapTarget] on both sides.
///
/// Wrap this *outside* the ink response, so the enlarged box is what receives
/// the gesture.
class TapTarget extends StatelessWidget {
  const TapTarget({super.key, required this.child, this.size = kMinTapTarget});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}

/// Shown when a detail route names a record that does not exist.
///
/// Detail paths double as push-notification deep links (`/deals/{id}`), so a
/// stale or mistyped id arrives from outside the app and must not throw —
/// the lookups behind these routes are lenient and land here instead.
class OpsNotFoundPage extends StatelessWidget {
  const OpsNotFoundPage({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: OpsDetailAppBar(title: title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 40, color: scheme.onSurfaceVariant),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail-page top bar: dark strip, circular back chevron, single-line title —
/// matches the design's `isDetail` overlay header rather than a generic
/// Material [AppBar].
class OpsDetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const OpsDetailAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: 'Back',
                child: InkWell(
                  // A deep link can open a detail with nothing beneath it, so
                  // fall back to the tab root rather than a dead back button.
                  onTap: () =>
                      context.canPop() ? context.pop() : context.go('/today'),
                  customBorder: const CircleBorder(),
                  child: TapTarget(
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outline),
                      ),
                      child: Text(
                        '‹',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.15,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small bordered, unfilled pill — the design's lead-row "Call" action.
/// Distinct from [StatusPill], which is filled and used for state/status
/// values (listing status, deal stage, document state).
///
/// With [onTap] it is a button in its own right, so tapping the pill inside a
/// row runs the pill's action rather than the row's.
class OutlinedTag extends StatelessWidget {
  const OutlinedTag(this.text, {super.key, this.onTap});

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: scheme.onSurface,
        ),
      ),
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: label,
      );
    }

    // The ink sits on the enlarged box rather than the pill, so the whole
    // 44dp region responds — a 26dp pill is a miss waiting to happen.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: TapTarget(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: label,
          ),
        ),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: context.estateExtras.eyebrow,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Eyebrow(title)),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class OpsCard extends StatelessWidget {
  const OpsCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A card that groups rows, each divided by a hairline except the last —
/// matches the design's roster / task / activity list containers.
///
/// The rows carry their own [InkWell]s, and ink paints into the nearest
/// [Material] ancestor. Without the transparent [Material] below the card's
/// own background the splash would land *behind* that background — tappable
/// rows would work but look dead — so the card supplies one, clipped to its
/// own radius.
class OpsListCard extends StatelessWidget {
  const OpsListCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final divider = context.estateExtras.divider;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (final (index, child) in children.indexed)
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: index == children.length - 1
                        ? null
                        : Border(bottom: BorderSide(color: divider)),
                  ),
                  child: child,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows of equal-width stat tiles.
///
/// Built from [Row]s rather than a [GridView] with a fixed `childAspectRatio`:
/// the labels are free text ("Comm. MTD", "Pending invites") and the user's
/// text scale is not ours to choose, so a ratio-derived height clips as soon
/// as one label wraps. [IntrinsicHeight] keeps tiles in a row matched while
/// still letting the tallest content set the height.
class StatGrid extends StatelessWidget {
  const StatGrid({
    super.key,
    required this.stats,
    this.columns = 3,
    this.onStatTap,
  });

  final List<Stat> stats;
  final int columns;

  /// Makes each tile a button. Left null the tiles stay read-out only, which
  /// is what most of the grids are — only the ones with somewhere to go
  /// (the Today KPIs) pass a handler.
  final ValueChanged<Stat>? onStatTap;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Stat>>[
      for (var i = 0; i < stats.length; i += columns)
        stats.sublist(i, (i + columns).clamp(0, stats.length)),
    ];

    return Column(
      children: [
        for (final (index, row) in rows.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) const SizedBox(width: 8),
                  Expanded(
                    child: column < row.length
                        ? _StatTile(
                            stat: row[column],
                            onTap: onStatTap == null
                                ? null
                                : () => onStatTap!(row[column]),
                          )
                        // Keeps a short final row aligned with the ones above
                        // instead of stretching its tiles across the width.
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat, this.onTap});

  final Stat stat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // "7" and "OPEN DEALS" are one fact, and a screen reader that reads
          // them as two stops delivers a number with nothing attached to it.
          child: MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    stat.v,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Eyebrow(stat.k),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FilterChips extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final option in options)
          _Chip(
            label: option,
            active: option == selected,
            scheme: scheme,
            onTap: () {
              opsTick();
              onSelected(option);
            },
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.active,
    required this.scheme,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? scheme.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: active ? BorderSide.none : BorderSide(color: scheme.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            // Filters get worked hard, one-handed, on site. The design draws
            // them at 33dp; this keeps the shape and pads the box out to a
            // thumb-sized one.
            constraints: const BoxConstraints(
              minHeight: kMinTapTarget,
              minWidth: kMinTapTarget,
            ),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(
    this.initials, {
    super.key,
    this.size = 38,
    this.onTap,
    this.semanticLabel,
  });

  final String initials;
  final double size;

  /// Turns the avatar into a button — the header avatar opens the profile.
  final VoidCallback? onTap;

  /// Initials alone read as two stray letters to a screen reader, so a
  /// tappable avatar names what it opens.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = Text(
      initials,
      style: TextStyle(
        fontSize: size * 0.34,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    );

    if (onTap == null) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          shape: BoxShape.circle,
        ),
        child: label,
      );
    }

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: TapTarget(
            size: size < kMinTapTarget ? kMinTapTarget : size,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}

class OpsRow extends StatelessWidget {
  const OpsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.onTap,
    this.dense = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Without this a screen reader announces the title, the subtitle and the
    // trailing value as three separate stops, so a roster row costs three
    // swipes and arrives as three unrelated fragments.
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dense ? 12 : 14),
          child: ConstrainedBox(
            // A row is the app's most-tapped control; the type alone can leave
            // a single-line one under a thumb-sized target.
            constraints: const BoxConstraints(minHeight: kMinTapTarget),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 13)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 7),
          Text(
            subtitle!,
            style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class DetailStatCard extends StatelessWidget {
  const DetailStatCard({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(label),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
