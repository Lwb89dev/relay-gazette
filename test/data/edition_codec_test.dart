import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/data/editions/edition_codec.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/edition_section.dart';
import 'package:relay_gazette/domain/entities/edition_source.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/filter_configuration.dart';
import 'package:relay_gazette/domain/entities/gazette_edition.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/entities/time_window.dart';

void main() {
  const codec = EditionCodec();

  test('encode/decode round-trips a full edition', () {
    final pubkey = NostrPublicKey.fromHex('a' * 64);
    final edition = GazetteEdition(
      id: 'edition-1',
      generatedAt: DateTime.utc(2026, 8, 23, 10),
      windowStart: DateTime.utc(2026, 8, 22, 10),
      windowEnd: DateTime.utc(2026, 8, 23, 10),
      source: EditionSource.personalNetwork,
      filterConfiguration: const FilterConfiguration(
        source: EditionSource.personalNetwork,
        timeWindow: EditionTimeWindow.twentyFourHours,
        thresholds: EngagementThresholds(minReactions: 5, minSatsReceived: 1000),
      ),
      sections: [
        EditionSection(
          id: 'top-stories',
          title: 'Top Stories',
          stories: [
            Story(
              id: 'note-1',
              kind: Story.kTextNote,
              author: Author(
                pubkey: pubkey,
                npub: 'npub1example',
                displayName: 'Jane',
                pictureUrl: 'https://example.com/pic.png',
              ),
              content: 'hello https://example.com/photo.jpg',
              createdAt: DateTime.utc(2026, 8, 23, 9),
              engagement: const EngagementCounts(
                reactions: 12,
                replies: 3,
                reposts: 1,
                zapCount: 2,
                zapSats: 2100,
              ),
              imageUrls: const ['https://example.com/photo.jpg'],
              links: const [],
            ),
          ],
        ),
      ],
    );

    final payload = codec.encodePayload(edition);
    final decoded = codec.decode(
      id: edition.id,
      generatedAt: edition.generatedAt,
      windowStart: edition.windowStart,
      windowEnd: edition.windowEnd,
      source: edition.source,
      payload: payload,
    );

    expect(decoded.id, edition.id);
    expect(decoded.storyCount, 1);
    expect(decoded.filterConfiguration.thresholds.minReactions, 5);
    expect(decoded.filterConfiguration.thresholds.minSatsReceived, 1000);
    expect(decoded.filterConfiguration.timeWindow.duration, const Duration(hours: 24));

    final story = decoded.sections.single.stories.single;
    expect(story.id, 'note-1');
    expect(story.author.displayName, 'Jane');
    expect(story.author.pubkey, pubkey);
    expect(story.engagement.zapSats, 2100);
    expect(story.imageUrls, ['https://example.com/photo.jpg']);
    expect(story.createdAt, DateTime.utc(2026, 8, 23, 9));
  });

  test('round-trips an edition with no qualifying sections', () {
    final edition = GazetteEdition(
      id: 'empty',
      generatedAt: DateTime.utc(2026, 8, 23),
      windowStart: DateTime.utc(2026, 8, 22),
      windowEnd: DateTime.utc(2026, 8, 23),
      source: EditionSource.trending,
      filterConfiguration: const FilterConfiguration(
        source: EditionSource.trending,
        timeWindow: EditionTimeWindow.fourHours,
      ),
      sections: const [],
    );

    final decoded = codec.decode(
      id: edition.id,
      generatedAt: edition.generatedAt,
      windowStart: edition.windowStart,
      windowEnd: edition.windowEnd,
      source: edition.source,
      payload: codec.encodePayload(edition),
    );

    expect(decoded.isEmpty, isTrue);
    expect(decoded.filterConfiguration.thresholds.isEmpty, isTrue);
  });
}
