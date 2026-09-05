import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/reading_preferences.dart';
import '../providers.dart';

class ThemePreferenceController extends AsyncNotifier<ThemePreference> {
  @override
  Future<ThemePreference> build() async {
    final settings = await ref.watch(settingsRepositoryProvider.future);
    return settings.getThemePreference();
  }

  Future<void> setPreference(ThemePreference preference) async {
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.setThemePreference(preference);
    state = AsyncData(preference);
  }
}

final themePreferenceProvider = AsyncNotifierProvider<ThemePreferenceController, ThemePreference>(
  ThemePreferenceController.new,
);

class BodyFontPreferenceController extends AsyncNotifier<BodyFontPreference> {
  @override
  Future<BodyFontPreference> build() async {
    final settings = await ref.watch(settingsRepositoryProvider.future);
    return settings.getBodyFontPreference();
  }

  Future<void> setPreference(BodyFontPreference preference) async {
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.setBodyFontPreference(preference);
    state = AsyncData(preference);
  }
}

final bodyFontPreferenceProvider = AsyncNotifierProvider<BodyFontPreferenceController, BodyFontPreference>(
  BodyFontPreferenceController.new,
);
