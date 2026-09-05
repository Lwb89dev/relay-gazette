import 'author.dart';
import 'engagement.dart';

/// A Nostr note normalized into something the UI can render without knowing
/// about NIP-01 events, tags, or kinds. `kind` lets the renderer branch on
/// content type: a plain [kTextNote] has no [title]/[summary]/[dTag]; a
/// NIP-23 [kLongFormArticle] does, with [content] holding the article's
/// Markdown body.
class Story {
  final String id;
  final int kind;
  final Author author;
  final String content;
  final DateTime createdAt;
  final EngagementCounts engagement;
  final List<String> imageUrls;
  final List<String> links;

  /// NIP-23 fields — null for anything that isn't [kLongFormArticle].
  final String? title;
  final String? summary;

  /// The article's `d` tag — its stable identifier, needed to address it
  /// again later (e.g. for a NIP-84 highlight's `a` tag).
  final String? dTag;

  const Story({
    required this.id,
    required this.kind,
    required this.author,
    required this.content,
    required this.createdAt,
    required this.engagement,
    this.imageUrls = const [],
    this.links = const [],
    this.title,
    this.summary,
    this.dTag,
  });

  static const kTextNote = 1;
  static const kLongFormArticle = 30023;

  bool get isLongFormArticle => kind == kLongFormArticle;

  /// A note made exclusively of naked URLs has no editorial body to place in
  /// an article column. This also catches extensionless image links from
  /// clients that omit NIP-92 `imeta` metadata, which cannot otherwise be
  /// identified reliably before fetching the remote resource.
  bool get isLinkOnlyPost {
    if (links.isEmpty) return false;
    final tokens = content.trim().split(RegExp(r'\s+'));
    return tokens.isNotEmpty && tokens.every(links.contains);
  }

  Story copyWith({EngagementCounts? engagement}) {
    return Story(
      id: id,
      kind: kind,
      author: author,
      content: content,
      createdAt: createdAt,
      engagement: engagement ?? this.engagement,
      imageUrls: imageUrls,
      links: links,
      title: title,
      summary: summary,
      dTag: dTag,
    );
  }

  @override
  bool operator ==(Object other) => other is Story && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
