import 'package:flutter_test/flutter_test.dart';
import 'package:ndk/ndk.dart';
import 'package:relay_gazette/data/signing/bunker_nostr_signer.dart';
import 'package:relay_gazette/domain/entities/nostr_event_draft.dart';

// Full connectWithBunkerUri() coverage would need a real relay round-trip
// (ndk.bunkers isn't independently injectable) — see TASKS.md. What's
// covered here is everything reachable without a network: the parts of
// the NostrSigner contract this class is responsible for on its own.
void main() {
  Ndk buildNdk() => Ndk(NdkConfig(eventVerifier: Bip340EventVerifier(), cache: MemCacheManager()));

  test('connect() is unsupported — a bunker session needs an explicit URI', () async {
    final signer = BunkerNostrSigner(buildNdk());
    expect(() => signer.connect(), throwsUnsupportedError);
  });

  test('isAvailable() is always true — a bunker connection only needs a relay, no local app', () async {
    final signer = BunkerNostrSigner(buildNdk());
    expect(await signer.isAvailable(), isTrue);
  });

  test('starts disconnected', () {
    final signer = BunkerNostrSigner(buildNdk());
    expect(signer.isConnected, isFalse);
    expect(signer.connectedPubkey, isNull);
  });

  test('sign() refuses before any bunker session is established', () async {
    final signer = BunkerNostrSigner(buildNdk());
    final event = UnsignedNostrEvent(kind: 1, content: 'hi', createdAt: DateTime.utc(2026, 8, 23));
    expect(await signer.sign(event), isNull);
  });

  test('disconnect() is a no-op (not an error) when nothing was ever connected', () async {
    final signer = BunkerNostrSigner(buildNdk());
    await signer.disconnect();
    expect(signer.isConnected, isFalse);
  });
}
