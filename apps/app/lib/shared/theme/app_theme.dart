import 'package:flutter/material.dart';

/// Material 3 theme, light and dark.
///
/// Everything is built RTL-safe from day one — directional insets
/// (`EdgeInsetsDirectional`, `start`/`end` rather than `left`/`right`) throughout
/// the app — so adding Arabic later is a translation job, not a re-layout. See
/// docs/adr/0005.
class AppTheme {
  const AppTheme._();

  /// Deep teal. Distinct from the red/gold that saturates UAE property
  /// branding, and it keeps the director's dashboard readable when the same
  /// screen also carries red expiry warnings and green targets.
  static const Color _seed = Color(0xFF0F6D6B);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 48dp keeps the attendance check-in button comfortably tappable with
          // a thumb while an agent is standing outside a property.
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsetsDirectional.symmetric(horizontal: 16),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    );
  }
}
