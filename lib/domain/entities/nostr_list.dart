import 'nostr_public_key.dart';

/// A NIP-51 "follow set" (kind 30000): a reader-curated, named group of
/// accounts, usable as an edition's author pool instead of their entire
/// contact list — e.g. "Bitcoin devs" or "Local friends".
class NostrList {
  final String id;
  final String title;
  final List<NostrPublicKey> members;

  const NostrList({required this.id, required this.title, required this.members});
}
