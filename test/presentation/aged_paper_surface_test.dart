import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/presentation/theme/aged_paper_surface.dart';
import 'package:relay_gazette/presentation/theme/app_theme.dart';
import 'package:relay_gazette/presentation/theme/gazette_colors.dart';

void main() {
  group('GazetteColors aging tones', () {
    test('dark theme has no aging gradient — edge/corner equal the flat paper tone', () {
      expect(GazetteColors.dark.paperEdge, GazetteColors.dark.paper);
      expect(GazetteColors.dark.paperCorner, GazetteColors.dark.paper);
    });

    test('sport theme has no aging gradient — edge/corner equal the flat paper tone', () {
      expect(GazetteColors.sport.paperEdge, GazetteColors.sport.paper);
      expect(GazetteColors.sport.paperCorner, GazetteColors.sport.paper);
    });

    test('light theme actually has distinct aging tones (center lighter than edges/corners)', () {
      final light = GazetteColors.light;
      expect(light.paperEdge, isNot(light.paper));
      expect(light.paperCorner, isNot(light.paper));
      // Center should be the lightest stop, corner the darkest.
      expect(light.paper.computeLuminance(), greaterThan(light.paperMuted.computeLuminance()));
      expect(light.paperMuted.computeLuminance(), greaterThan(light.paperEdge.computeLuminance()));
      expect(light.paperEdge.computeLuminance(), greaterThan(light.paperCorner.computeLuminance()));
    });
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
