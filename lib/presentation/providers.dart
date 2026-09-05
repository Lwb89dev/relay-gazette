import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:ndk/ndk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/editions/edition_repository_impl.dart';
import '../data/feed/composite_feed_provider.dart';
import '../data/nostr/http_nip05_resolver.dart';
import '../data/nostr/ndk_client_factory.dart';
import '../data/nostr/ndk_event_broadcaster.dart';
import '../data/nostr/ndk_public_key_codec.dart';
import '../data/nostr/relay_feed_provider.dart';
import '../data/nostr/relay_highlights_repository.dart';
import '../data/primal/primal_cache_client.dart';
import '../data/primal/primal_feed_provider.dart';
import '../data/settings/shared_prefs_settings_repository.dart';
import '../domain/entities/nostr_public_key.dart';
import '../domain/repositories/edition_repository.dart';
import '../domain/repositories/event_broadcaster.dart';
import '../domain/repositories/feed_provider.dart';
import '../domain/repositories/highlights_repository.dart';
import '../domain/repositories/nip05_resolver.dart';
import '../domain/repositories/settings_repository.dart';
import '../domain/usecases/generate_edition.dart';
import '../domain/usecases/parse_user_identity.dart';
import '../storage/database.dart';

/// Composition root: this is the only file that knows every layer at once
/// (domain interfaces wired to their data-layer implementations). Everything
/// downstream depends on interfaces, not on this file.
final ndkProvider = Provider<Ndk>((ref) {
  final ndk = createNdk();
  ref.onDispose(ndk.destroy);
  // Fire-and-forget: `Ndk`'s own constructor already starts connecting the
  // fixed default relays, but a reader's own added relays (Settings →
  // Relays, persisted via `SettingsRepository.getCustomRelayUrls`) aren't
  // part of that bootstrap set, so they're layered on here — the first
  // time anything actually needs `Ndk` (feed fetch, signing, wallet, or
  // opening the Relays section itself), not unconditionally at app start.
  // Deliberately not wired into the widget tree root: doing that made
  // every widget test that renders the app attempt real network
  // connections, which is both undesirable in tests and pointless for
  // screens that never touch relays at all.
  ref.read(settingsRepositoryProvider.future).then((settings) async {
    final saved = await settings.getCustomRelayUrls();
    if (saved.isNotEmpty) await ndk.relays.reconnectRelays(saved);
  });
  return ndk;
});

final publicKeyCodecProvider = Provider<NdkPublicKeyCodec>(
  (ref) => const NdkPublicKeyCodec(),
);

final parseUserIdentityProvider = Provider<ParseUserIdentity>((ref) {
  return ParseUserIdentity(ref.watch(publicKeyCodecProvider));
});

final relayFeedProviderProvider = Provider<RelayFeedProvider>((ref) {
  return RelayFeedProvider(ref.watch(ndkProvider));
});

final primalCacheClientProvider = Provider<PrimalCacheClient>((ref) {
  return WebSocketPrimalCacheClient();
});

final primalFeedProviderProvider = Provider<PrimalFeedProvider>((ref) {
  return PrimalFeedProvider(ref.watch(primalCacheClientProvider));
});

/// The single [FeedProvider] the rest of the app depends on: personal
/// network via relays, trending/discovery via Primal.
final feedProviderProvider = Provider<FeedProvider>((ref) {
  return CompositeFeedProvider(
    personalNetwork: ref.watch(relayFeedProviderProvider),
    trending: ref.watch(primalFeedProviderProvider),
  );
});

final generateEditionProvider = Provider<GenerateEdition>((ref) {
  return GenerateEdition(ref.watch(feedProviderProvider));
});

final eventBroadcasterProvider = Provider<EventBroadcaster>((ref) {
  return NdkEventBroadcaster(ref.watch(ndkProvider));
});

final highlightsRepositoryProvider = Provider<HighlightsRepository>((ref) {
  return RelayHighlightsRepository(ref.watch(ndkProvider));
});

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final nip05ResolverProvider = Provider<Nip05Resolver>((ref) {
  return HttpNip05Resolver(ref.watch(httpClientProvider));
});

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final editionRepositoryProvider = Provider<EditionRepository>((ref) {
  return EditionRepositoryImpl(ref.watch(databaseProvider));
});

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final settingsRepositoryProvider = FutureProvider<SettingsRepository>((
  ref,
) async {
  final prefs = await ref.watch(sharedPreferencesProvider.future);
  return SharedPrefsSettingsRepository(prefs);
});

/// The reader's saved identity, if onboarding has already happened.
/// `null` (successfully resolved) means "show onboarding".
final savedPubkeyProvider = FutureProvider<NostrPublicKey?>((ref) async {
  final settings = await ref.watch(settingsRepositoryProvider.future);
  return settings.getSavedPubkey();
});
