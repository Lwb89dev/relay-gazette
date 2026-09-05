import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows onboarding when no npub is saved yet', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: RelayGazetteApp()));
    await tester.pumpAndSettle();

    expect(find.text('The Relay Gazette'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('rejects an invalid npub with an inline error, without navigating', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: RelayGazetteApp()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'not-a-key');
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('valid npub'), findsOneWidget);
  });
}
