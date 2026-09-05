import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lightning/nip57_zap_service.dart';
import '../../data/nostr/relay_defaults.dart';
import '../../data/signing/amber_nostr_signer.dart';
import '../../data/signing/bunker_nostr_signer.dart';
import '../../domain/entities/author.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/repositories/nostr_signer.dart';
import '../../domain/repositories/null_nostr_signer.dart';
import '../../domain/repositories/zap_service.dart';
import '../../domain/usecases/create_highlight.dart';
import '../../domain/usecases/interactions.dart';
import '../providers.dart';

/// Kept as single instances for the app's lifetime — see each signer's own
/// doc comment for why (in-memory session state that shouldn't be
/// recreated on every rebuild).
final amberSignerProvider = Provider<AmberNostrSigner>((ref) => AmberNostrSigner());

final bunkerSignerProvider = Provider<BunkerNostrSigner>((ref) {
  return BunkerNostrSigner(ref.watch(ndkProvider));
});

final isAmberAvailableProvider = FutureProvider<bool>((ref) {
  return ref.watch(amberSignerProvider).isAvailable();
});

/// The signer the reader has actually connected — [NullNostrSigner] until
/// they connect one via either method, so every consumer can depend on a
/// plain `NostrSigner` rather than a nullable one.
class SignerConnectionController extends Notifier<NostrSigner> {
  @override
  NostrSigner build() => const NullNostrSigner();

  Future<NostrPublicKey?> connectWithAmber() async {
    final signer = ref.read(amberSignerProvider);
    final pubkey = await signer.connect();
    if (pubkey != null) state = signer;
    return pubkey;
  }

  Future<NostrPublicKey?> connectWithBunker(String bunkerUri) async {
    final signer = ref.read(bunkerSignerProvider);
    final pubkey = await signer.connectWithBunkerUri(bunkerUri);
    if (pubkey != null) state = signer;
    return pubkey;
  }

  Future<void> disconnect() async {
    await state.disconnect();
    state = const NullNostrSigner();
  }
}

final signerConnectionProvider = NotifierProvider<SignerConnectionController, NostrSigner>(
  SignerConnectionController.new,
);

/// The connected signer's profile, resolved so Settings can show a name
/// instead of "Connected — [npub]" (an npub is 63 characters — not
/// something a reader should have to read to confirm who they're signed
/// in as). `null` while nothing is connected.
final connectedSignerAuthorProvider = FutureProvider<Author?>((ref) async {
  final pubkey = ref.watch(signerConnectionProvider).connectedPubkey;
  if (pubkey == null) return null;
  return ref.watch(relayFeedProviderProvider).resolveViewer(pubkey);
});

final reactToStoryProvider = Provider<ReactToStory>((ref) {
  return ReactToStory(ref.watch(signerConnectionProvider), ref.watch(eventBroadcasterProvider));
});

final repostStoryProvider = Provider<RepostStory>((ref) {
  return RepostStory(ref.watch(signerConnectionProvider), ref.watch(eventBroadcasterProvider));
});

final replyToStoryProvider = Provider<ReplyToStory>((ref) {
  return ReplyToStory(ref.watch(signerConnectionProvider), ref.watch(eventBroadcasterProvider));
});

final createHighlightProvider = Provider<CreateHighlight>((ref) {
  return CreateHighlight(ref.watch(signerConnectionProvider), ref.watch(eventBroadcasterProvider));
});

final zapServiceProvider = Provider<ZapService>((ref) {
  return Nip57ZapService(
    ref.watch(httpClientProvider),
    signer: ref.watch(signerConnectionProvider),
    relayHints: kDefaultBootstrapRelays,
  );
});
