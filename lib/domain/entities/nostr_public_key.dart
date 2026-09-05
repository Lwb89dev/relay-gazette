/// A validated Nostr public key, carried through the app as hex — never as
/// a raw, unchecked string. Encoding/decoding to `npub` (NIP-19) is injected
/// so the domain layer does not depend on a specific Nostr library.
class NostrPublicKey {
  final String hex;

  const NostrPublicKey._(this.hex);

  /// Wraps an already-known-good 64-char lowercase hex pubkey.
  factory NostrPublicKey.fromHex(String hex) {
    final normalized = hex.trim().toLowerCase();
    if (!_isValidHex(normalized)) {
      throw InvalidPublicKeyException(
        'Not a valid 32-byte hex public key: $hex',
      );
    }
    return NostrPublicKey._(normalized);
  }

  static bool _isValidHex(String value) {
    return value.length == 64 && RegExp(r'^[0-9a-f]{64}$').hasMatch(value);
  }

  static bool looksLikeHex(String value) =>
      _isValidHex(value.trim().toLowerCase());

  @override
  bool operator ==(Object other) => other is NostrPublicKey && other.hex == hex;

  @override
  int get hashCode => hex.hashCode;

  @override
  String toString() => hex;
}

/// Decodes/encodes npub <-> hex. Implemented in the data layer against
/// whichever Nostr library is in use, so the domain stays protocol-agnostic.
abstract class Bech32PublicKeyCodec {
  NostrPublicKey decodeNpub(String npub);
  String encodeNpub(NostrPublicKey pubkey);
  bool isNpub(String value);
}

class InvalidPublicKeyException implements Exception {
  final String message;
  const InvalidPublicKeyException(this.message);

  @override
  String toString() => 'InvalidPublicKeyException: $message';
}
