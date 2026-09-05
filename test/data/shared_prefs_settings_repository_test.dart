import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/data/settings/shared_prefs_settings_repository.dart';
import 'package:relay_gazette/domain/entities/reading_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('theme preference defaults to system when nothing has been saved', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsSettingsRepository(await SharedPreferences.getInstance());

    expect(await repo.getThemePreference(), ThemePreference.system);
  });

  test('theme preference round-trips through save/load', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsSettingsRepository(await SharedPreferences.getInstance());

    await repo.setThemePreference(ThemePreference.sport);

    expect(await repo.getThemePreference(), ThemePreference.sport);
  });

  test('body font preference defaults to serif when nothing has been saved', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsSettingsRepository(await SharedPreferences.getInstance());

    expect(await repo.getBodyFontPreference(), BodyFontPreference.serif);
  });

  test('body font preference round-trips through save/load', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsSettingsRepository(await SharedPreferences.getInstance());

    await repo.setBodyFontPreference(BodyFontPreference.sansSerif);

    expect(await repo.getBodyFontPreference(), BodyFontPreference.sansSerif);
  });

  test('custom relay URLs default to empty when nothing has been saved', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsSettingsRepository(await SharedPreferences.getInstance());

    expect(await repo.getCustomRelayUrls(), isEmpty);
  });

  test('custom relay URLs round-trip through save/load', () async {
    SharedPreferences.setMockInitialValues({});
    final repo = SharedPrefsSettingsRepository(await SharedPreferences.getInstance());

    await repo.setCustomRelayUrls(['wss://relay.one.example', 'wss://relay.two.example']);

    expect(await repo.getCustomRelayUrls(), ['wss://relay.one.example', 'wss://relay.two.example']);
  });
}
