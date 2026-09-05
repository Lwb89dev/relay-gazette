import '../../domain/entities/author.dart';
import '../../domain/entities/edition_section.dart';
import '../../domain/entities/edition_source.dart';
import '../../domain/entities/engagement.dart';
import '../../domain/entities/filter_configuration.dart';
import '../../domain/entities/gazette_edition.dart';
import '../../domain/entities/nostr_public_key.dart';
import '../../domain/entities/story.dart';
import '../../domain/entities/time_window.dart';

/// Converts a [GazetteEdition] to/from the plain JSON structure stored in
/// [Editions.payloadJson]. Kept separate from the Drift row mapping so it
/// can be unit tested without a database.
class EditionCodec {
  const EditionCodec();

  Map<String, dynamic> encodePayload(GazetteEdition edition) {
    return {
      'filterConfiguration': _encodeFilterConfiguration(
        edition.filterConfiguration,
      ),
      'sections': edition.sections.map(_encodeSection).toList(),
    };
  }

  GazetteEdition decode({
    required String id,
    required DateTime generatedAt,
    required DateTime windowStart,
    required DateTime windowEnd,
    required EditionSource source,
    required Map<String, dynamic> payload,
  }) {
    return GazetteEdition(
      id: id,
      generatedAt: generatedAt,
      windowStart: windowStart,
      windowEnd: windowEnd,
      source: source,
      filterConfiguration: _decodeFilterConfiguration(
        payload['filterConfiguration'] as Map<String, dynamic>,
      ),
      sections: (payload['sections'] as List)
          .map((s) => _decodeSection(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _encodeFilterConfiguration(FilterConfiguration config) {
    return {
      'source': config.source.name,
      'timeWindowHours': config.timeWindow.duration.inHours,
      'customListId': config.customListId,
      'thresholds': {
        'minReactions': config.thresholds.minReactions,
        'minReplies': config.thresholds.minReplies,
        'minReposts': config.thresholds.minReposts,
        'minZaps': config.thresholds.minZaps,
        'minSatsReceived': config.thresholds.minSatsReceived,
      },
    };
  }

  FilterConfiguration _decodeFilterConfiguration(Map<String, dynamic> json) {
    final thresholds = json['thresholds'] as Map<String, dynamic>;
    return FilterConfiguration(
      source: EditionSource.values.byName(json['source'] as String),
      timeWindow: EditionTimeWindow.custom(
        Duration(hours: json['timeWindowHours'] as int),
      ),
      customListId: json['customListId'] as String?,
      thresholds: EngagementThresholds(
        minReactions: thresholds['minReactions'] as int?,
        minReplies: thresholds['minReplies'] as int?,
        minReposts: thresholds['minReposts'] as int?,
        minZaps: thresholds['minZaps'] as int?,
        minSatsReceived: thresholds['minSatsReceived'] as int?,
      ),
    );
  }

  Map<String, dynamic> _encodeSection(EditionSection section) {
    return {
      'id': section.id,
      'title': section.title,
      'stories': section.stories.map(_encodeStory).toList(),
    };
  }

  EditionSection _decodeSection(Map<String, dynamic> json) {
    return EditionSection(
      id: json['id'] as String,
      title: json['title'] as String,
      stories: (json['stories'] as List)
          .map((s) => _decodeStory(s as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _encodeStory(Story story) {
    return {
      'id': story.id,
      'kind': story.kind,
      'author': _encodeAuthor(story.author),
      'content': story.content,
      'createdAtUtcMillis': story.createdAt.millisecondsSinceEpoch,
      'engagement': {
        'reactions': story.engagement.reactions,
        'replies': story.engagement.replies,
        'reposts': story.engagement.reposts,
        'zapCount': story.engagement.zapCount,
        'zapSats': story.engagement.zapSats,
      },
      'imageUrls': story.imageUrls,
      'links': story.links,
      'title': story.title,
      'summary': story.summary,
      'dTag': story.dTag,
    };
  }

  Story _decodeStory(Map<String, dynamic> json) {
    final engagement = json['engagement'] as Map<String, dynamic>;
    return Story(
      id: json['id'] as String,
      kind: json['kind'] as int,
      author: _decodeAuthor(json['author'] as Map<String, dynamic>),
      content: json['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        json['createdAtUtcMillis'] as int,
        isUtc: true,
      ),
      engagement: EngagementCounts(
        reactions: engagement['reactions'] as int,
        replies: engagement['replies'] as int,
        reposts: engagement['reposts'] as int,
        zapCount: engagement['zapCount'] as int,
        zapSats: engagement['zapSats'] as int,
      ),
      imageUrls: (json['imageUrls'] as List).cast<String>(),
      links: (json['links'] as List).cast<String>(),
      title: json['title'] as String?,
      summary: json['summary'] as String?,
      dTag: json['dTag'] as String?,
    );
  }

  Map<String, dynamic> _encodeAuthor(Author author) {
    return {
      'pubkeyHex': author.pubkey.hex,
      'npub': author.npub,
      'displayName': author.displayName,
      'name': author.name,
      'pictureUrl': author.pictureUrl,
      'nip05': author.nip05,
      'lightningAddress': author.lightningAddress,
    };
  }

  Author _decodeAuthor(Map<String, dynamic> json) {
    return Author(
      pubkey: NostrPublicKey.fromHex(json['pubkeyHex'] as String),
      npub: json['npub'] as String,
      displayName: json['displayName'] as String?,
      name: json['name'] as String?,
      pictureUrl: json['pictureUrl'] as String?,
      nip05: json['nip05'] as String?,
      lightningAddress: json['lightningAddress'] as String?,
    );
  }
}
