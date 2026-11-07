import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/presentation/theme/aged_paper_surface.dart';
import 'package:relay_gazette/presentation/theme/app_theme.dart';
import 'package:relay_gazette/presentation/theme/gazette_colors.dart';

void main() {
  group('GazetteColors aging tones', () {
    test('dark theme has a restrained vignette toward the corners', () {
      final dark = GazetteColors.dark;
      expect(dark.paperEdge, isNot(dark.paper));
      expect(dark.paperCorner, isNot(dark.paper));
      expect(
        dark.paper.computeLuminance(),
        greaterThan(dark.paperEdge.computeLuminance()),
      );
      expect(
        dark.paperEdge.computeLuminance(),
        greaterThan(dark.paperCorner.computeLuminance()),
      );
    });

    test('sport theme has subtle tonal variation in its pink stock', () {
      final sport = GazetteColors.sport;
      expect(sport.paperEdge, isNot(sport.paper));
      expect(sport.paperCorner, isNot(sport.paper));
      expect(
        sport.paper.computeLuminance(),
        greaterThan(sport.paperEdge.computeLuminance()),
      );
      expect(
        sport.paperEdge.computeLuminance(),
        greaterThan(sport.paperCorner.computeLuminance()),
      );
    });

    test(
      'light theme actually has distinct aging tones (center lighter than edges/corners)',
      () {
        final light = GazetteColors.light;
        expect(light.paperEdge, isNot(light.paper));
        expect(light.paperCorner, isNot(light.paper));
        // Center should be the lightest stop, corner the darkest.
        expect(
          light.paper.computeLuminance(),
          greaterThan(light.paperMuted.computeLuminance()),
        );
        expect(
          light.paperMuted.computeLuminance(),
          greaterThan(light.paperEdge.computeLuminance()),
        );
        expect(
          light.paperEdge.computeLuminance(),
          greaterThan(light.paperCorner.computeLuminance()),
        );
      },
    );
  });

  group('AgedPaperSurface', () {
    Future<void> pumpSurface(WidgetTester tester, ThemeData theme) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: AgedPaperSurface(child: SizedBox(width: 300, height: 600)),
          ),
        ),
      );
    }

    testWidgets('renders without error in the light theme', (tester) async {
      await pumpSurface(tester, AppTheme.light());
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error in the dark theme', (tester) async {
      await pumpSurface(tester, AppTheme.dark());
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders without error in the sport theme', (tester) async {
      await pumpSurface(tester, AppTheme.sport());
      expect(tester.takeException(), isNull);
    });
  });
}
