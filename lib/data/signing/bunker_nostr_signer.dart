import 'package:ndk/data_layer/repositories/signers/nip46_event_signer.dart';
import 'package:ndk/ndk.dart';

import '../../domain/entities/nostr_event_draft.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/repositories/nostr_signer.dart';

/// [NostrSigner] backed by a NIP-46 remote signer ("bunker") — a service
/// or a second device that holds the reader's private key and signs on
/// request over a relay, per nostr-protocol/nips/46.md. Works on every
/// platform this app runs on, unlike [AmberNostrSigner] (Android-only).
///
/// [connectWithBunkerUri] generates a fresh, disposable local keypair to
/// talk to the bunker (ndk's `Bunkers.connectWithBunkerUrl` handles this) —
/// that keypair is transport-only, never the reader's actual identity key,
/// and this app never sees or asks for the real one.
///
/// Same trust posture as [AmberNostrSigner]: a bunker is a separate,
/// untrusted process reached over the network, so [sign] independently
/// verifies the signature it gets back rather than assuming a connection
/// that resolved once is trustworthy forever.
class BunkerNostrSigner implements NostrSigner, BunkerCapableSigner {
  final Ndk _ndk;
  final EventVerifier _verifier;

  Nip46EventSigner? _remoteSigner;
  NostrPublicKey? _connectedPubkey;

  BunkerNostrSigner(this._ndk, {EventVerifier? verifier}) : _verifier = verifier ?? Bip340EventVerifier();

  @override
  bool get isConnected => _connectedPubkey != null;

  @override
  NostrPublicKey? get connectedPubkey => _connectedPubkey;

  /// A bunker connection just needs a reachable relay — there's no local
  /// app to check for, unlike Amber.
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<NostrPublicKey?> connect() {
    throw UnsupportedError('BunkerNostrSigner needs a bunker:// URI — call connectWithBunkerUri instead.');
  }

  @override
  Future<NostrPublicKey?> connectWithBunkerUri(String bunkerUri) async {
    try {
      final connection = await _ndk.bunkers.connectWithBunkerUrl(bunkerUri);
      if (connection == null) return null;

      final signer = _ndk.bunkers.createSigner(connection);
      final pubkeyHex = await signer.getPublicKeyAsync();
      final pubkey = NostrPublicKey.fromHex(pubkeyHex);

      _remoteSigner = signer;
      _connectedPubkey = pubkey;
      return pubkey;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> disconnect() async {
    await _remoteSigner?.dispose();
    _remoteSigner = null;
    _connectedPubkey = null;
  }

  @override
  Future<SignedNostrEvent?> sign(UnsignedNostrEvent event) async {
    final signer = _remoteSigner;
    final pubkey = _connectedPubkey;
    if (signer == null || pubkey == null) return null;

    final unsignedEvent = Nip01Event(
      pubKey: pubkey.hex,
      kind: event.kind,
      tags: event.tags,
      content: event.content,
      createdAt: event.createdAt.millisecondsSinceEpoch ~/ 1000,
    );

    try {
      final signedEvent = await signer.sign(unsignedEvent);
      if (signedEvent.pubKey.toLowerCase() != pubkey.hex) return null;
      if (!await _verifier.verify(signedEvent)) return null;

      return SignedNostrEvent(
        id: signedEvent.id,
        pubkeyHex: signedEvent.pubKey,
        kind: signedEvent.kind,
        content: signedEvent.content,
        tags: signedEvent.tags,
        createdAt: DateTime.fromMillisecondsSinceEpoch(signedEvent.createdAt * 1000, isUtc: true),
        signature: signedEvent.sig!,
      );
    } catch (_) {
      return null;
    }
  }
}
