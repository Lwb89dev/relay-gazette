import 'nostr_public_key.dart';

/// Normalized author/profile info. Populated from NIP-01 kind:0 metadata,
/// but the domain layer never sees the raw event.
class Author {
  final NostrPublicKey pubkey;
  final String npub;
  final String? displayName;
  final String? name;
  final String? pictureUrl;
  final String? nip05;
  final String? lightningAddress;

  const Author({
    required this.pubkey,
    required this.npub,
    this.displayName,
    this.name,
    this.pictureUrl,
    this.nip05,
    this.lightningAddress,
  });

  factory Author.unknown(NostrPublicKey pubkey, {required String npub}) {
    return Author(pubkey: pubkey, npub: npub);
  }

  /// Best available label for this author: display name, then name, then a
  /// shortened npub as a last resort.
  String get label {
    if (displayName != null && displayName!.trim().isNotEmpty) {
      return displayName!.trim();
    }
    if (name != null && name!.trim().isNotEmpty) {
      return name!.trim();
    }
    return '${npub.substring(0, 12)}…';
  }
}
