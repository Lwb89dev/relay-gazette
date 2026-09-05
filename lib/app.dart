import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'domain/entities/reading_preferences.dart';
import 'presentation/archive/edition_archive_page.dart';
import 'presentation/common/state_views.dart';
import 'presentation/onboarding/onboarding_flow.dart';
import 'presentation/providers.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/theme_providers.dart';

class RelayGazetteApp extends ConsumerWidget {
  const RelayGazetteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themePreference = ref.watch(themePreferenceProvider).value ?? ThemePreference.system;
    final bodyFont = ref.watch(bodyFontPreferenceProvider).value ?? BodyFontPreference.serif;

    // "system" keeps following the OS light/dark setting live; an explicit
    // choice (light/dark/sport) is pinned regardless of the OS setting.
    final ThemeData theme;
    final ThemeData darkTheme;
    final ThemeMode themeMode;
    if (themePreference == ThemePreference.system) {
      theme = AppTheme.light(bodyFont: bodyFont);
      darkTheme = AppTheme.dark(bodyFont: bodyFont);
      themeMode = ThemeMode.system;
    } else {
      final pinned = AppTheme.forPreference(themePreference, bodyFont, Brightness.light);
      theme = pinned;
      darkTheme = pinned;
      themeMode = ThemeMode.light;
    }

    return MaterialApp(
      title: 'The Relay Gazette',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const _StartupGate(),
    );
  }
}

/// Decides between onboarding and the archive based on whether a reader
/// identity is already saved on-device — this check never touches the
/// network, so it resolves instantly even offline.
class _StartupGate extends ConsumerWidget {
  const _StartupGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPubkeyProvider);
    return saved.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: GazetteStateView(
          icon: Icons.error_outline,
          title: 'Couldn\'t start The Relay Gazette',
          message: describeGazetteError(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(savedPubkeyProvider),
        ),
      ),
      data: (pubkey) => pubkey == null ? const OnboardingFlow() : const EditionArchivePage(),
    );
  }
}
