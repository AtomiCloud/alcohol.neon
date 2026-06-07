import 'package:flutter/material.dart';

/// Semantic accent colours extracted from alcohol.argon's components (Tailwind
/// classes, not the neutral theme tokens). argon has no single "brand" colour —
/// it's a neutral base plus this semantic map + playful card gradients.
class AppColors {
  static const money = Color(0xFF059669); // emerald-600 (donate / complete)
  static const moneyDark = Color(0xFF34D399); // emerald-400
  static const freeze = Color(0xFF2563EB); // blue-600
  static const freezeDark = Color(0xFF60A5FA); // blue-400
  static const streak = Color(0xFFF59E0B); // amber-500 (🔥 current streak)
  static const best = Color(0xFFEAB308); // yellow-500 (👑 best streak)
  static const vacation = Color(0xFFCA8A04); // yellow-600
  static const fail = Color(0xFFDC2626); // red-600 (missed days)

  /// Per-card gradient top-borders (rotating), straight from argon's HabitCard.
  static const cardGradients = <List<Color>>[
    [
      Color(0xFF3B82F6),
      Color(0xFF818CF8),
      Color(0xFFA855F7),
    ], // blue→indigo→purple
    [
      Color(0xFF34D399),
      Color(0xFF2DD4BF),
      Color(0xFF22D3EE),
    ], // emerald→teal→cyan
    [
      Color(0xFFFB923C),
      Color(0xFFE879F9),
      Color(0xFF8B5CF6),
    ], // orange→fuchsia→violet
    [
      Color(0xFFEC4899),
      Color(0xFFFB7185),
      Color(0xFFFB923C),
    ], // pink→rose→orange
  ];

  /// Stable gradient pick for a card, keyed by its id.
  static List<Color> gradientFor(String? key) =>
      cardGradients[(key?.hashCode ?? 0).abs() % cardGradients.length];
}

/// App theme — faithfully mirrors alcohol.argon's palette (the shadcn *neutral*
/// theme: near-black primary on greyscale surfaces, with green only as a sparing
/// accent), translated to a lighter, iOS-native Flutter feel: the system font
/// (San Francisco on iOS), grouped white cards on a soft scaffold, soft corners.
/// `themeMode: system` follows the device. Values converted from argon's
/// globals.css `oklch(...)` tokens.
class AppTheme {
  // Brand emerald — used ONLY as an accent (success / positive), like argon.
  static const _accent = Color(0xFF059669); // emerald-600
  static const _accentDark = Color(0xFF34D399); // emerald-400
  // Logo teal (sign-in / launcher), distinct from UI colours.
  static const brandTeal = Color(0xFF1B5453);

  static const _cardRadius = 14.0;
  static const _ctrlRadius = 12.0;

  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF171717), // argon --primary oklch(0.205)
      onPrimary: Color(0xFFFAFAFA), // --primary-foreground oklch(0.985)
      primaryContainer: Color(0xFFF5F5F5),
      onPrimaryContainer: Color(0xFF171717),
      secondary: Color(0xFFF5F5F5), // --secondary oklch(0.97)
      onSecondary: Color(0xFF171717),
      tertiary: _accent, // brand accent
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFD1FAE5),
      onTertiaryContainer: Color(0xFF064E3B),
      error: Color(0xFFDC2626), // --destructive
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: Color(0xFFFFFFFF), // cards
      onSurface: Color(0xFF0A0A0A), // --foreground oklch(0.145)
      onSurfaceVariant: Color(0xFF737373), // --muted-foreground oklch(0.556)
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFFAFAFA),
      surfaceContainer: Color(0xFFF5F5F5),
      surfaceContainerHigh: Color(0xFFF0F0F0),
      surfaceContainerHighest: Color(0xFFEAEAEA),
      outline: Color(0xFFD9D9D9),
      outlineVariant: Color(0xFFE5E5E5), // --border oklch(0.922)
      shadow: Color(0x14000000),
    );
    return _base(scheme, scaffold: const Color(0xFFF4F4F5));
  }

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFE5E5E5), // argon dark --primary oklch(0.922)
      onPrimary: Color(0xFF171717),
      primaryContainer: Color(0xFF262626),
      onPrimaryContainer: Color(0xFFFAFAFA),
      secondary: Color(0xFF262626), // --secondary oklch(0.269)
      onSecondary: Color(0xFFFAFAFA),
      tertiary: _accentDark,
      onTertiary: Color(0xFF052E1B),
      tertiaryContainer: Color(0xFF064E3B),
      onTertiaryContainer: Color(0xFFD1FAE5),
      error: Color(0xFFF87171), // dark --destructive oklch(0.704)
      onError: Color(0xFF450A0A),
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      surface: Color(0xFF171717), // --card oklch(0.205)
      onSurface: Color(0xFFFAFAFA),
      onSurfaceVariant: Color(0xFFA1A1A1), // --muted-foreground oklch(0.708)
      surfaceContainerLowest: Color(0xFF0A0A0A),
      surfaceContainerLow: Color(0xFF141414),
      surfaceContainer: Color(0xFF1C1C1C),
      surfaceContainerHigh: Color(0xFF262626),
      surfaceContainerHighest: Color(0xFF303030),
      outline: Color(0xFF333333),
      outlineVariant: Color(0xFF242424),
      shadow: Color(0x33000000),
    );
    return _base(scheme, scaffold: const Color(0xFF0A0A0A));
  }

  static ThemeData _base(ColorScheme scheme, {required Color scaffold}) {
    final isLight = scheme.brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      // No bundled font → platform system font (SF on iOS).
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cardRadius),
          side: BorderSide(
            color: scheme.outlineVariant,
            width: isLight ? 1 : 0.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_ctrlRadius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(50),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_ctrlRadius),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_ctrlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_ctrlRadius),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_ctrlRadius),
          borderSide: BorderSide(color: scheme.onSurface, width: 1.5),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 0.5,
        space: 0.5,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : null,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
