import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/presentation/relays/relay_providers.dart';
import 'package:relay_gazette/presentation/settings/settings_page.dart';
import 'package:relay_gazette/presentation/signing/signing_providers.dart';
import 'package:relay_gazette/presentation/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows a Support section with the Lightning donation address', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Real signer-availability and relay-connection checks reach a
          // platform channel and open live websockets respectively — both
          // are irrelevant to this test and must be stubbed out.
          isAmberAvailableProvider.overrideWith((ref) async => false),
          connectedRelaysProvider.overrideWith((ref) => Stream.value(const <String>{})),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SettingsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // The Support section is the last one in the list — scroll it into
    // view, since a Sliver list doesn't build items far outside the
    // viewport.
    await tester.scrollUntilVisible(
      find.text('lwb89@blink.sv'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Support'), findsOneWidget);
    expect(find.text('Support The Relay Gazette'), findsOneWidget);
    expect(find.text('lwb89@blink.sv'), findsOneWidget);
  });
}
