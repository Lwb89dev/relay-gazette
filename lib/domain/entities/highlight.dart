import 'author.dart';

/// A NIP-84 highlight: a reader marking a passage of a story or article as
/// worth remembering — Nostr's version of underlining a passage in a book.
class Highlight {
  final String id;
  final String text;
  final Author author;
  final DateTime createdAt;

  const Highlight({required this.id, required this.text, required this.author, required this.createdAt});
}
