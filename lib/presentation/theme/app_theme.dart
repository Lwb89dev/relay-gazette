import 'package:flutter/material.dart';

import '../../domain/entities/reading_preferences.dart';
import 'gazette_colors.dart';

/// A newspaper-first type system, applied to three palettes — see
/// [GazetteColors] — and an optional serif/sans-serif choice for body
/// copy (headlines always stay serif; that's identity, not readability).
/// Deliberately not a "crypto app" look in any of them. See
/// ARCHITECTURE.md, "Visual design".
class AppTheme {
  AppTheme._();

  static const headlineFamily = 'PlayfairDisplay';
  static const serifBodyFamily = 'SourceSerif4';
  static const uiFamily = 'Inter';

  static ThemeData light({
    BodyFontPreference bodyFont = BodyFontPreference.serif,
  }) => _build(GazetteColors.light, Brightness.light, bodyFont);

  static ThemeData dark({
    BodyFontPreference bodyFont = BodyFontPreference.serif,
  }) => _build(GazetteColors.dark, Brightness.dark, bodyFont);

  static ThemeData sport({
    BodyFontPreference bodyFont = BodyFontPreference.serif,
  }) => _build(GazetteColors.sport, Brightness.light, bodyFont);

  static ThemeData forPreference(
    ThemePreference theme,
    BodyFontPreference bodyFont,
    Brightness systemBrightness,
  ) {
    return switch (theme) {
      ThemePreference.light => light(bodyFont: bodyFont),
      ThemePreference.dark => dark(bodyFont: bodyFont),
      ThemePreference.sport => sport(bodyFont: bodyFont),
      ThemePreference.system =>
        systemBrightness == Brightness.dark
            ? dark(bodyFont: bodyFont)
            : light(bodyFont: bodyFont),
    };
  }

  static ThemeData _build(
    GazetteColors colors,
    Brightness brightness,
    BodyFontPreference bodyFont,
  ) {
    final bodyFamily = bodyFont == BodyFontPreference.serif
        ? serifBodyFamily
        : uiFamily;
    final isSport = colors.style == GazetteVisualStyle.sport;
    final controlRadius = BorderRadius.circular(2);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Seeded first so every Material 3 role (onSurfaceVariant, outline,
      // surfaceContainer, ...) gets a value consistent with `brightness` —
      // the direct ColorScheme(...) constructor leaves unlisted roles at
      // fixed defaults regardless of brightness, which is how the "sport"
      // palette ended up with unreadable text in some widgets despite
      // `ink`/`paper` themselves being correct. Only the roles this app
      // actually styles by hand are overridden below.
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: colors.accent,
            brightness: brightness,
          ).copyWith(
            surface: colors.paper,
            onSurface: colors.ink,
            surfaceContainerLowest: colors.paper,
            surfaceContainerLow: colors.paperMuted.withValues(alpha: 0.38),
            surfaceContainer: colors.paperMuted,
            surfaceContainerHigh: colors.paperMuted,
            surfaceContainerHighest: colors.rule,
            onSurfaceVariant: colors.inkFaded,
            outline: colors.rule,
            outlineVariant: colors.rule.withValues(alpha: 0.7),
            primary: colors.ink,
            onPrimary: colors.paper,
            secondary: colors.accent,
            onSecondary: colors.paper,
            tertiary: colors.accent,
            onTertiary: colors.paper,
            error: colors.accent,
            onError: colors.paper,
          ),
      scaffoldBackgroundColor: colors.paper,
      fontFamily: uiFamily,
      dividerColor: colors.rule,
      dividerTheme: DividerThemeData(
        color: colors.rule,
        thickness: 1,
        space: 1,
      ),
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        elevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleTextStyle: TextStyle(
          fontFamily: headlineFamily,
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: colors.ink,
        ),
        iconTheme: IconThemeData(color: colors.ink, size: 22),
        shape: Border(bottom: BorderSide(color: colors.rule)),
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colors.paperMuted.withValues(alpha: 0.34),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: colors.rule),
          borderRadius: controlRadius,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: colors.paper,
          disabledBackgroundColor: colors.rule,
          disabledForegroundColor: colors.paper,
          textStyle: const TextStyle(
            fontFamily: uiFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.ink),
          textStyle: const TextStyle(
            fontFamily: uiFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.accent,
          textStyle: const TextStyle(
            fontFamily: uiFamily,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colors.ink,
        foregroundColor: colors.paper,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        extendedTextStyle: const TextStyle(
          fontFamily: uiFamily,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colors.inkFaded,
        textColor: colors.ink,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.inkFaded,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.paper,
        selectedColor: colors.ink,
        disabledColor: colors.paperMuted,
        labelStyle: TextStyle(
          fontFamily: uiFamily,
          fontWeight: FontWeight.w600,
          color: colors.ink,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: uiFamily,
          fontWeight: FontWeight.w700,
          color: colors.paper,
        ),
        side: BorderSide(color: colors.rule),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.paperMuted.withValues(alpha: 0.58),
        labelStyle: TextStyle(color: colors.inkFaded),
        floatingLabelStyle: TextStyle(color: colors.accent),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: colors.rule),
          borderRadius: controlRadius,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.rule),
          borderRadius: controlRadius,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: colors.accent, width: 1.5),
          borderRadius: controlRadius,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.ink,
        contentTextStyle: TextStyle(color: colors.paper, fontFamily: uiFamily),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
        behavior: SnackBarBehavior.floating,
      ),
    );

    return base.copyWith(
      // Every role below is a *replacement* TextStyle, not a merge, so
      // `.apply(...)`'s color doesn't carry over to it — each one repeats
      // `color: colors.ink` explicitly. Leaving it off (as this used to)
      // left the role's color unset, and this app's own contrast wasn't
      // what determined the fallback: Flutter's Material widgets fall back
      // to *their own* light/dark heuristic in that case, which produced
      // unreadable near-white text in exactly the two themes with a light
      // `paper` (light and sport) — the bug reported as "il font deve
      // essere nero, non bianco".
      textTheme: base.textTheme
          .apply(bodyColor: colors.ink, displayColor: colors.ink)
          .copyWith(
            displayLarge: TextStyle(
              fontFamily: headlineFamily,
              fontWeight: FontWeight.w700,
              fontSize: isSport ? 46 : 44,
              height: 1.02,
              letterSpacing: isSport ? -1.1 : -0.65,
              color: colors.ink,
            ),
            headlineLarge: TextStyle(
              fontFamily: headlineFamily,
              fontWeight: FontWeight.w700,
              fontSize: 30,
              height: 1.08,
              letterSpacing: -0.35,
              color: colors.ink,
            ),
            headlineMedium: TextStyle(
              fontFamily: headlineFamily,
              fontWeight: FontWeight.w700,
              fontSize: 23,
              height: 1.12,
              letterSpacing: -0.2,
              color: colors.ink,
            ),
            headlineSmall: TextStyle(
              fontFamily: headlineFamily,
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1.16,
              color: colors.ink,
            ),
            titleLarge: TextStyle(
              fontFamily: headlineFamily,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
            titleMedium: TextStyle(
              fontFamily: headlineFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
            bodyLarge: TextStyle(
              fontFamily: bodyFamily,
              fontSize: 18,
              height: 1.52,
              color: colors.ink,
            ),
            bodyMedium: TextStyle(
              fontFamily: bodyFamily,
              fontSize: 15.5,
              height: 1.46,
              color: colors.ink,
            ),
            bodySmall: TextStyle(
              fontFamily: bodyFamily,
              fontSize: 13,
              height: 1.4,
              color: colors.inkFaded,
            ),
            labelLarge: TextStyle(
              fontFamily: uiFamily,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.75,
              color: colors.ink,
            ),
            labelMedium: TextStyle(
              fontFamily: uiFamily,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.inkFaded,
              letterSpacing: 0.4,
            ),
            labelSmall: TextStyle(
              fontFamily: uiFamily,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: colors.inkFaded,
              letterSpacing: 0.6,
            ),
          ),
    );
  }
}
