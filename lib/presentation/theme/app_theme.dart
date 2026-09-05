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

  static ThemeData light({BodyFontPreference bodyFont = BodyFontPreference.serif}) =>
      _build(GazetteColors.light, Brightness.light, bodyFont);

  static ThemeData dark({BodyFontPreference bodyFont = BodyFontPreference.serif}) =>
      _build(GazetteColors.dark, Brightness.dark, bodyFont);

  static ThemeData sport({BodyFontPreference bodyFont = BodyFontPreference.serif}) =>
      _build(GazetteColors.sport, Brightness.light, bodyFont);

  static ThemeData forPreference(ThemePreference theme, BodyFontPreference bodyFont, Brightness systemBrightness) {
    return switch (theme) {
      ThemePreference.light => light(bodyFont: bodyFont),
      ThemePreference.dark => dark(bodyFont: bodyFont),
      ThemePreference.sport => sport(bodyFont: bodyFont),
      ThemePreference.system =>
        systemBrightness == Brightness.dark ? dark(bodyFont: bodyFont) : light(bodyFont: bodyFont),
    };
  }

  static ThemeData _build(GazetteColors colors, Brightness brightness, BodyFontPreference bodyFont) {
    final bodyFamily = bodyFont == BodyFontPreference.serif ? serifBodyFamily : uiFamily;

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
      colorScheme: ColorScheme.fromSeed(seedColor: colors.accent, brightness: brightness).copyWith(
        surface: colors.paper,
        onSurface: colors.ink,
        primary: colors.ink,
        onPrimary: colors.paper,
        secondary: colors.accent,
        onSecondary: colors.paper,
        error: colors.accent,
        onError: colors.paper,
      ),
      scaffoldBackgroundColor: colors.paper,
      fontFamily: uiFamily,
      dividerColor: colors.rule,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.paper,
        foregroundColor: colors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colors.paper,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(side: BorderSide(color: colors.rule)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.ink,
          foregroundColor: colors.paper,
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.rule),
          shape: const RoundedRectangleBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.paperMuted,
        border: OutlineInputBorder(borderSide: BorderSide(color: colors.rule)),
        enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.rule)),
        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.ink, width: 1.5)),
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
              fontSize: 44,
              height: 1.05,
              letterSpacing: -0.5,
              color: colors.ink,
            ),
            headlineLarge: TextStyle(
              fontFamily: headlineFamily,
              fontWeight: FontWeight.w700,
              fontSize: 28,
              height: 1.1,
              color: colors.ink,
            ),
            headlineMedium: TextStyle(
              fontFamily: headlineFamily,
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.15,
              color: colors.ink,
            ),
            headlineSmall: TextStyle(
              fontFamily: headlineFamily,
              fontWeight: FontWeight.w600,
              fontSize: 19,
              height: 1.2,
              color: colors.ink,
            ),
            bodyLarge: TextStyle(fontFamily: bodyFamily, fontSize: 17, height: 1.45, color: colors.ink),
            bodyMedium: TextStyle(fontFamily: bodyFamily, fontSize: 15, height: 1.4, color: colors.ink),
            labelLarge: TextStyle(
              fontFamily: uiFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
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
