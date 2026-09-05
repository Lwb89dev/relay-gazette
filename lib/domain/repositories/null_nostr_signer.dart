import '../entities/nostr_event_draft.dart';
import '../entities/nostr_public_key.dart';
import 'nostr_signer.dart';

/// The "no signer connected yet" state, as a real [NostrSigner] instead of
/// a nullable one — every interaction usecase and [ZapService] can depend
/// on a plain `NostrSigner`, never `NostrSigner?`, and simply gets refused
/// (never a crash) until the reader actually connects one.
class NullNostrSigner implements NostrSigner {
  const NullNostrSigner();

  @override
  bool get isConnected => false;

  @override
  NostrPublicKey? get connectedPubkey => null;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<NostrPublicKey?> connect() async => null;

  @override
  Future<void> disconnect() async {}

  @override
  Future<SignedNostrEvent?> sign(UnsignedNostrEvent event) async => null;
}
