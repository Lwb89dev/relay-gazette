import '../entities/nostr_public_key.dart';
import '../entities/reading_preferences.dart';

/// Local device preferences. Never synchronized anywhere — Nostr is the
/// only identity, and application settings stay on-device unless a future
/// explicit sync feature is added.
abstract class SettingsRepository {
  Future<NostrPublicKey?> getSavedPubkey();
  Future<void> setSavedPubkey(NostrPublicKey pubkey);
  Future<void> clearSavedPubkey();

  Future<ThemePreference> getThemePreference();
  Future<void> setThemePreference(ThemePreference preference);

  Future<BodyFontPreference> getBodyFontPreference();
  Future<void> setBodyFontPreference(BodyFontPreference preference);

  /// Relay URLs the reader has added on top of the app's built-in defaults.
  /// Empty until the reader adds one — the defaults alone are not stored
  /// here, so they can change between app versions without migrating
  /// anything the reader typed in.
  Future<List<String>> getCustomRelayUrls();
  Future<void> setCustomRelayUrls(List<String> urls);
}
