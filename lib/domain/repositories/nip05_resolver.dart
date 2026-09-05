import '../entities/nostr_public_key.dart';

/// Resolves a NIP-05 identifier ("name@domain.com") to the public key it
/// maps to, via the domain's `/.well-known/nostr.json`. An alternative to
/// typing/pasting an npub during onboarding.
abstract class Nip05Resolver {
  /// Returns null if the identifier is malformed, the domain doesn't
  /// answer, or it doesn't list that name — all ordinary "that didn't
  /// work" outcomes, not exceptional ones.
  Future<NostrPublicKey?> resolve(String identifier);
}
