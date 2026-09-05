import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/nostr_public_key.dart';
import '../../domain/entities/reading_preferences.dart';
import '../../domain/repositories/settings_repository.dart';

class SharedPrefsSettingsRepository implements SettingsRepository {
  static const _pubkeyKey = 'saved_pubkey_hex';
  static const _themeKey = 'theme_preference';
  static const _bodyFontKey = 'body_font_preference';
  static const _customRelaysKey = 'custom_relay_urls';

  final SharedPreferences _prefs;

  SharedPrefsSettingsRepository(this._prefs);

  @override
  Future<NostrPublicKey?> getSavedPubkey() async {
    final hex = _prefs.getString(_pubkeyKey);
    if (hex == null) return null;
    return NostrPublicKey.fromHex(hex);
  }

  @override
  Future<void> setSavedPubkey(NostrPublicKey pubkey) async {
    await _prefs.setString(_pubkeyKey, pubkey.hex);
  }

  @override
  Future<void> clearSavedPubkey() async {
    await _prefs.remove(_pubkeyKey);
  }

  @override
  Future<ThemePreference> getThemePreference() async {
    final name = _prefs.getString(_themeKey);
    return ThemePreference.values.firstWhere(
      (v) => v.name == name,
      orElse: () => ThemePreference.system,
    );
  }

  @override
  Future<void> setThemePreference(ThemePreference preference) async {
    await _prefs.setString(_themeKey, preference.name);
  }

  @override
  Future<BodyFontPreference> getBodyFontPreference() async {
    final name = _prefs.getString(_bodyFontKey);
    return BodyFontPreference.values.firstWhere(
      (v) => v.name == name,
      orElse: () => BodyFontPreference.serif,
    );
  }

  @override
  Future<void> setBodyFontPreference(BodyFontPreference preference) async {
    await _prefs.setString(_bodyFontKey, preference.name);
  }

  @override
  Future<List<String>> getCustomRelayUrls() async {
    return _prefs.getStringList(_customRelaysKey) ?? const [];
  }

  @override
  Future<void> setCustomRelayUrls(List<String> urls) async {
    await _prefs.setStringList(_customRelaysKey, urls);
  }
}
