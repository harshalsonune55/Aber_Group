import 'package:flutter/material.dart';

/// Color roles the Estate Ops screens need beyond [ColorScheme] — the design's
/// dimmer "eyebrow" label, hairline dividers, chip hover state and the
/// tinted approval-request card.
///
/// Registered on every [ThemeData] the app uses (see [AppTheme] and
/// `EstateOpsTheme`) so the same widget tree reads correctly whether it is
/// wrapped in the forced-dark phone theme or the ambient light/dark M3 theme
/// used behind the navigation rail on larger screens.
@immutable
class EstateOpsExtras extends ThemeExtension<EstateOpsExtras> {
  const EstateOpsExtras({
    required this.eyebrow,
    required this.divider,
    required this.chipHover,
    required this.requestCard,
    required this.requestBorder,
  });

  final Color eyebrow;
  final Color divider;
  final Color chipHover;
  final Color requestCard;
  final Color requestBorder;

  factory EstateOpsExtras.fromScheme(ColorScheme scheme) => EstateOpsExtras(
    eyebrow: scheme.onSurfaceVariant,
    divider: scheme.outlineVariant,
    chipHover: scheme.surfaceContainerHighest,
    requestCard: scheme.secondaryContainer,
    requestBorder: scheme.outline,
  );

  @override
  EstateOpsExtras copyWith({
    Color? eyebrow,
    Color? divider,
    Color? chipHover,
    Color? requestCard,
    Color? requestBorder,
  }) {
    return EstateOpsExtras(
      eyebrow: eyebrow ?? this.eyebrow,
      divider: divider ?? this.divider,
      chipHover: chipHover ?? this.chipHover,
      requestCard: requestCard ?? this.requestCard,
      requestBorder: requestBorder ?? this.requestBorder,
    );
  }

  @override
  EstateOpsExtras lerp(ThemeExtension<EstateOpsExtras>? other, double t) {
    if (other is! EstateOpsExtras) return this;
    return EstateOpsExtras(
      eyebrow: Color.lerp(eyebrow, other.eyebrow, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      chipHover: Color.lerp(chipHover, other.chipHover, t)!,
      requestCard: Color.lerp(requestCard, other.requestCard, t)!,
      requestBorder: Color.lerp(requestBorder, other.requestBorder, t)!,
    );
  }
}

extension EstateOpsExtrasContext on BuildContext {
  EstateOpsExtras get estateExtras =>
      Theme.of(this).extension<EstateOpsExtras>() ??
      EstateOpsExtras.fromScheme(Theme.of(this).colorScheme);
}
