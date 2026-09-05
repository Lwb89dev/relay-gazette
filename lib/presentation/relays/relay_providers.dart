import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Reader-added relays layered on top of the fixed defaults
/// (`kDefaultBootstrapRelays`).
///
/// The seed connections `Ndk` opens at construction time are fixed by
/// `NdkConfig.bootstrapRelays` and don't include anything the reader adds
/// later — see `ndkProvider` for where saved relays get reconnected at
/// startup. This controller only owns the persisted list itself, plus
/// pushing a newly-added relay onto the already-running `Ndk` right away.
class RelayListController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final settings = await ref.watch(settingsRepositoryProvider.future);
    return settings.getCustomRelayUrls();
  }

  Future<String?> addRelay(String rawUrl) async {
    final url = normalizeRelayUrl(rawUrl);
    if (url == null) return 'Enter a valid relay address, e.g. wss://relay.example.com';

    final current = state.value ?? const [];
    if (current.contains(url)) return null;

    final updated = [...current, url];
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.setCustomRelayUrls(updated);
    state = AsyncData(updated);

    final ndk = ref.read(ndkProvider);
    unawaited(ndk.relays.reconnectRelays([url]));
    return null;
  }

  Future<void> removeRelay(String url) async {
    final current = state.value ?? const [];
    final updated = current.where((r) => r != url).toList();
    final settings = await ref.read(settingsRepositoryProvider.future);
    await settings.setCustomRelayUrls(updated);
    state = AsyncData(updated);
  }
}

final relayListProvider = AsyncNotifierProvider<RelayListController, List<String>>(
  RelayListController.new,
);

/// Which relay URLs are, right now, actually open sockets — surfaced so
/// Settings → Relays can show a real connected/not-connected status per
/// relay instead of leaving the reader to guess whether "it's not finding
/// anything" means "no relays reachable" or "nothing new in this window".
final connectedRelaysProvider = StreamProvider<Set<String>>((ref) {
  final ndk = ref.watch(ndkProvider);
  return ndk.relays.relayConnectivityChanges.map(
    (relays) => relays.keys.where(ndk.relays.isRelayConnected).toSet(),
  );
});

/// `wss://` only — plaintext `ws://` relays leak every query and event a
/// reader sends over the network in the clear, so the app doesn't offer it
/// even though the protocol technically allows it.
String? normalizeRelayUrl(String rawUrl) {
  final trimmed = rawUrl.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.scheme != 'wss' || uri.host.isEmpty) return null;
  return uri.toString();
}
