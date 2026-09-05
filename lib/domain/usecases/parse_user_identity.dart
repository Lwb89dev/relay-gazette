import '../entities/nostr_public_key.dart';

/// Turns whatever a reader typed into onboarding (an `npub1…` or a raw hex
/// key) into a validated [NostrPublicKey]. Kept as a pure usecase, decoupled
/// from any Nostr library, so it's cheap to unit test.
class ParseUserIdentity {
  final Bech32PublicKeyCodec _codec;

  const ParseUserIdentity(this._codec);

  NostrPublicKey call(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      throw const InvalidPublicKeyException('Enter an npub to continue.');
    }
    if (_codec.isNpub(trimmed)) {
      return _codec.decodeNpub(trimmed);
    }
    if (NostrPublicKey.looksLikeHex(trimmed)) {
      return NostrPublicKey.fromHex(trimmed);
    }
    throw InvalidPublicKeyException(
      'That doesn\'t look like a valid npub: $trimmed',
    );
  }
}
