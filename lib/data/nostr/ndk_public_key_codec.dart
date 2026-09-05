import 'package:ndk/ndk.dart';

import '../../domain/entities/nostr_public_key.dart';

/// [Bech32PublicKeyCodec] backed by ndk's NIP-19 implementation. Isolated
/// here so the domain layer never imports ndk directly.
class NdkPublicKeyCodec implements Bech32PublicKeyCodec {
  const NdkPublicKeyCodec();

  @override
  bool isNpub(String value) => Nip19.isPubkey(value.trim());

  @override
  NostrPublicKey decodeNpub(String npub) {
    try {
      final hex = Nip19.decode(npub.trim());
      return NostrPublicKey.fromHex(hex);
    } catch (e) {
      throw InvalidPublicKeyException('Could not decode npub: $npub');
    }
  }

  @override
  String encodeNpub(NostrPublicKey pubkey) => Nip19.encodePubKey(pubkey.hex);
}
