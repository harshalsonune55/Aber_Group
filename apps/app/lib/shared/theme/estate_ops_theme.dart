import 'package:flutter/material.dart';

import '../responsive/aber_shell.dart';
import 'estate_ops_extras.dart';

/// Dark, white-accent theme matching the Estate Ops staff-app design.
///
/// This is the product's look at every width. It used to apply only to the
/// phone branch, leaving desktop on the ambient teal M3 theme — which meant
/// resizing the window changed what app you appeared to be using. Screen
/// content reads colors from [ColorScheme] / [EstateOpsExtras] rather than
/// literal hex, so nothing needs to know which theme is in force.
class EstateOpsTheme {
  const EstateOpsTheme._();

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFFFFF),
      onPrimary: Color(0xFF111113),
      secondary: Color(0xFFC4C4C9),
      onSecondary: Color(0xFF111113),
      secondaryContainer: Color(0xFF1E1E22),
      onSecondaryContainer: Color(0xFFF4F4F5),
      tertiary: Color(0xFFC4C4C9),
      onTertiary: Color(0xFF111113),
      error: Color(0xFFEF5350),
      onError: Color(0xFF111113),
      surface: Color(0xFF111113),
      onSurface: Color(0xFFF4F4F5),
      surfaceContainerLowest: Color(0xFF0B0B0C),
      surfaceContainerLow: Color(0xFF161619),
      surfaceContainer: Color(0xFF1A1A1D),
      surfaceContainerHigh: Color(0xFF1E1E22),
      surfaceContainerHighest: Color(0xFF26262B),
      onSurfaceVariant: Color(0xFFA1A1A6),
      outline: Color(0xFF3A3A41),
      outlineVariant: Color(0xFF2A2A2F),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFF4F4F5),
      onInverseSurface: Color(0xFF111113),
      inversePrimary: Color(0xFF111113),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          minimumSize: const Size(64, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontWeight: FontWeight.w600),
        bodyMedium: TextStyle(height: 1.4),
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      extensions: const [
        EstateOpsExtras(
          eyebrow: Color(0xFF8B8B93),
          divider: Color(0xFF232327),
          chipHover: Color(0xFF1F1F23),
          requestCard: Color(0xFF1E1E22),
          requestBorder: Color(0xFF3A3A41),
        ),
      ],
    );
  }
}

/// Applies [EstateOpsTheme.dark] and caps the content width, for the routes
/// that sit *outside* the shell on the root navigator — sign-in, sign-up and
/// the profile. [AberShell] does the same for everything inside it; without
/// this those three screens would render against the ambient theme and stretch
/// the full width of a desktop window.
class EstateOpsCompactTheme extends StatelessWidget {
  const EstateOpsCompactTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: EstateOpsTheme.dark(),
      // The auth screens cap themselves at a form's width; only the profile
      // needs this, and a second cap over a narrower one is harmless.
      child: ReadableWidth(child: child),
    );
  }
}
