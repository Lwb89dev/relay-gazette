import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:ndk/ndk.dart';

import '../../domain/entities/nostr_event_draft.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/repositories/nostr_signer.dart';

/// [NostrSigner] backed by a NIP-55 Android signer app (Amber) via
/// [MainActivity]'s method channel. Reading the Gazette never requires
/// this — it only exists to unlock interaction (spec §19-20).
///
/// The public key returned from `get_public_key` isn't persisted here on
/// purpose: on Android, Amber can be asked to remember the grant and skip
/// the confirmation prompt on future calls, so re-deriving it each launch
/// (by asking again) is both simpler and avoids this app caching identity
/// data it doesn't strictly need.
///
/// Everything that comes back over the method channel is untrusted input —
/// it originates from a separate Android app via an Intent, which any app
/// registered for the same `nostrsigner:` scheme could in principle answer
/// instead of the real signer. [sign] therefore re-derives the event id and
/// verifies the BIP-340 signature itself (via [_verifier]) rather than
/// trusting the returned JSON at face value, and rejects anything claiming
/// a different pubkey than the one the reader connected. A malformed or
/// forged response is treated the same as a plain decline — callers only
/// ever see null, never a parse exception.
class AmberNostrSigner implements NostrSigner {
  static const _channel = MethodChannel('com.relaygazette.relay_gazette/amber');

  final EventVerifier _verifier;

  AmberNostrSigner({EventVerifier? verifier})
    : _verifier = verifier ?? Bip340EventVerifier();

  NostrPublicKey? _connectedPubkey;

  @override
  bool get isConnected => _connectedPubkey != null;

  @override
  NostrPublicKey? get connectedPubkey => _connectedPubkey;

  @override
  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAppInstalled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<NostrPublicKey?> connect() async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'getPublicKey',
        {
          'permissions': jsonEncode(const [
            {'type': 'sign_event', 'kind': 1},
            {'type': 'sign_event', 'kind': 6},
            {'type': 'sign_event', 'kind': 7},
          ]),
        },
      );
      final raw = response?['result'] as String?;
      if (raw == null) return null;

      final hex = Nip19.isPubkey(raw) ? Nip19.decode(raw) : raw;
      final pubkey = NostrPublicKey.fromHex(hex);
      _connectedPubkey = pubkey;
      return pubkey;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> disconnect() async {
    _connectedPubkey = null;
  }

  @override
  Future<SignedNostrEvent?> sign(UnsignedNostrEvent event) async {
    final pubkey = _connectedPubkey;
    if (pubkey == null) return null;

    final unsignedJson = jsonEncode({
      'pubkey': pubkey.hex,
      'kind': event.kind,
      'content': event.content,
      'tags': event.tags,
      'created_at': event.createdAt.millisecondsSinceEpoch ~/ 1000,
    });

    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('signEvent', {
            'eventJson': unsignedJson,
            'currentUser': pubkey.hex,
            'id': DateTime.now().microsecondsSinceEpoch.toString(),
          });
      final signedJson = response?['event'] as String?;
      if (signedJson == null) return null;

      final decoded = jsonDecode(signedJson) as Map<String, dynamic>;

      // Reject anything for an identity other than the one the reader
      // connected — a well-behaved signer never does this, but nothing
      // stops a different app answering the same Intent scheme from trying.
      final returnedPubkey = (decoded['pubkey'] as String?)?.toLowerCase();
      if (returnedPubkey != pubkey.hex) return null;

      final candidate = Nip01Event(
        id: decoded['id'] as String,
        pubKey: returnedPubkey!,
        kind: decoded['kind'] as int,
        tags: (decoded['tags'] as List)
            .map((t) => (t as List).cast<String>())
            .toList(),
        content: decoded['content'] as String,
        sig: decoded['sig'] as String,
        createdAt: decoded['created_at'] as int,
      );

      // Re-derive the id and check the signature ourselves rather than
      // trusting the claim — this is the one place in the app that
      // publishes something under the reader's identity.
      if (!await _verifier.verify(candidate)) return null;

      return SignedNostrEvent(
        id: candidate.id,
        pubkeyHex: candidate.pubKey,
        kind: candidate.kind,
        content: candidate.content,
        tags: candidate.tags,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          candidate.createdAt * 1000,
          isUtc: true,
        ),
        signature: candidate.sig!,
      );
    } on PlatformException {
      return null;
    } catch (_) {
      // Malformed/unexpected response shape from whatever answered the
      // Intent — treat it as a decline, not a crash.
      return null;
    }
  }
}
