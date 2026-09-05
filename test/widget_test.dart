import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> skipToSignIn(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('onboarding starts with an explanation of how an edition is built', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: RelayGazetteApp()));
    await tester.pumpAndSettle();

    expect(find.text('How your edition\nis built'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('reaches the sign-in step after paging through the intro', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: RelayGazetteApp()));
    await tester.pumpAndSettle();

    await skipToSignIn(tester);

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('rejects an invalid npub with an inline error, without navigating', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: RelayGazetteApp()));
    await tester.pumpAndSettle();

    await skipToSignIn(tester);

    await tester.enterText(find.byType(TextField), 'not-a-key');
    await tester.ensureVisible(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('valid npub'), findsOneWidget);
  });
}
