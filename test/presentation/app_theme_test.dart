import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/reading_preferences.dart';
import 'package:relay_gazette/presentation/theme/app_theme.dart';
import 'package:relay_gazette/presentation/theme/gazette_colors.dart';

void main() {
  GazetteColors colorsOf(ThemeData theme) => theme.extension<GazetteColors>()!;

  test('light()/dark()/sport() each carry their own distinct palette', () {
    final light = colorsOf(AppTheme.light());
    final dark = colorsOf(AppTheme.dark());
    final sport = colorsOf(AppTheme.sport());

    expect(light.paper, GazetteColors.light.paper);
    expect(dark.paper, GazetteColors.dark.paper);
    expect(sport.paper, GazetteColors.sport.paper);
    expect({light.paper, dark.paper, sport.paper}, hasLength(3)); // all different
  });

  test('forPreference resolves an explicit choice regardless of system brightness', () {
    final sportViaDarkSystem = AppTheme.forPreference(
      ThemePreference.sport,
      BodyFontPreference.serif,
      Brightness.dark,
    );
    expect(colorsOf(sportViaDarkSystem).paper, GazetteColors.sport.paper);
  });

  test('forPreference(system, ...) follows the reported system brightness', () {
    final lightSystem = AppTheme.forPreference(
      ThemePreference.system,
      BodyFontPreference.serif,
      Brightness.light,
    );
    final darkSystem = AppTheme.forPreference(
      ThemePreference.system,
      BodyFontPreference.serif,
      Brightness.dark,
    );
    expect(colorsOf(lightSystem).paper, GazetteColors.light.paper);
    expect(colorsOf(darkSystem).paper, GazetteColors.dark.paper);
  });

  test('body font preference changes body text but never the headline family', () {
    final serif = AppTheme.light(bodyFont: BodyFontPreference.serif);
    final sans = AppTheme.light(bodyFont: BodyFontPreference.sansSerif);

    expect(serif.textTheme.bodyLarge!.fontFamily, AppTheme.serifBodyFamily);
    expect(sans.textTheme.bodyLarge!.fontFamily, AppTheme.uiFamily);

    expect(serif.textTheme.displayLarge!.fontFamily, AppTheme.headlineFamily);
    expect(sans.textTheme.displayLarge!.fontFamily, AppTheme.headlineFamily);
  });

  group('text stays readable against its background in every theme (WCAG AA, >= 4.5:1)', () {
    // Regression test: the sport theme's own ink/paper pair was already
    // high-contrast, but building ColorScheme(...) directly (rather than
    // seeding it) left secondary roles — onSurfaceVariant in particular,
    // used for things like input hint text — at fixed defaults unrelated
    // to `brightness`, so *some* text was unreadable even though the
    // theme's headline colors looked fine.
    for (final entry in {'light': AppTheme.light(), 'dark': AppTheme.dark(), 'sport': AppTheme.sport()}.entries) {
      final scheme = entry.value.colorScheme;

      test('${entry.key}: onSurface vs surface', () {
        expect(_contrastRatio(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(4.5));
      });

      test('${entry.key}: onSurfaceVariant vs surface', () {
        expect(_contrastRatio(scheme.onSurfaceVariant, scheme.surface), greaterThanOrEqualTo(4.5));
      });

      test('${entry.key}: onPrimary vs primary', () {
        expect(_contrastRatio(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
      });

      test('${entry.key}: onSecondary vs secondary', () {
        expect(_contrastRatio(scheme.onSecondary, scheme.secondary), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('textTheme roles resolve a real color against paper (not the Material fallback)', () {
    // Regression test for a real bug: `TextTheme.copyWith(displayLarge:
    // TextStyle(...))` *replaces* that role rather than merging into it, so
    // the color `.apply(bodyColor: ..., displayColor: ...)` had just set
    // was silently dropped for every role listed with its own TextStyle
    // below (all but labelMedium/labelSmall, which happened to set `color`
    // inline already). With no color, text using those roles — including
    // the masthead's "THE RELAY GAZETTE" (displayLarge) — fell back to
    // Flutter's own light/dark heuristic instead of this theme's `ink`,
    // rendering unreadable near-white text on the light and sport themes'
    // paper-colored backgrounds. Reported as "il font deve essere nero,
    // non bianco".
    const roles = [
      'displayLarge',
      'headlineLarge',
      'headlineMedium',
      'headlineSmall',
      'bodyLarge',
      'bodyMedium',
      'labelLarge',
    ];

    Color? roleColor(TextTheme textTheme, String role) => switch (role) {
      'displayLarge' => textTheme.displayLarge!.color,
      'headlineLarge' => textTheme.headlineLarge!.color,
      'headlineMedium' => textTheme.headlineMedium!.color,
      'headlineSmall' => textTheme.headlineSmall!.color,
      'bodyLarge' => textTheme.bodyLarge!.color,
      'bodyMedium' => textTheme.bodyMedium!.color,
      'labelLarge' => textTheme.labelLarge!.color,
      _ => throw ArgumentError(role),
    };

    for (final entry in {'light': AppTheme.light(), 'dark': AppTheme.dark(), 'sport': AppTheme.sport()}.entries) {
      final surface = entry.value.colorScheme.surface;
      for (final role in roles) {
        test('${entry.key}: $role has an explicit, high-contrast color', () {
          final color = roleColor(entry.value.textTheme, role);
          expect(color, isNotNull, reason: '$role must not rely on Material\'s fallback text color');
          expect(_contrastRatio(color!, surface), greaterThanOrEqualTo(4.5));
        });
      }
    }
  });
}

double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
