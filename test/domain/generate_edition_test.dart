import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/edition_source.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/filter_configuration.dart';
import 'package:relay_gazette/domain/entities/nostr_list.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/entities/time_window.dart';
import 'package:relay_gazette/domain/repositories/feed_provider.dart';
import 'package:relay_gazette/domain/usecases/generate_edition.dart';

class _FakeFeedProvider implements FeedProvider {
  List<Story> personalNetworkStories = const [];
  List<Story> trendingStories = const [];
  List<Story> webOfTrustStories = const [];
  List<Story> listStories = const [];
  ({DateTime since, DateTime until})? lastPersonalNetworkWindow;
  String? lastRequestedListId;

  @override
  bool get supportsTrending => true;

  @override
  bool get supportsWebOfTrust => true;

  @override
  bool get supportsLists => true;

  @override
  Future<Author> resolveViewer(NostrPublicKey pubkey) async =>
      Author.unknown(pubkey, npub: 'npub1viewer');

  @override
  Future<List<Story>> fetchPersonalNetworkStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) async {
    lastPersonalNetworkWindow = (since: since, until: until);
    return personalNetworkStories;
  }

  @override
  Future<List<Story>> fetchTrendingStories({
    required DateTime since,
    required DateTime until,
  }) async {
    return trendingStories;
  }

  @override
  Future<List<Story>> fetchWebOfTrustStories({
    required NostrPublicKey pubkey,
    required DateTime since,
    required DateTime until,
  }) async {
    return webOfTrustStories;
  }

  @override
  Future<List<NostrList>> fetchLists(NostrPublicKey owner) async => const [];

  @override
  Future<List<Story>> fetchStoriesFromList({
    required NostrPublicKey owner,
    required String listId,
    required DateTime since,
    required DateTime until,
  }) async {
    lastRequestedListId = listId;
    return listStories;
  }
}

Story _story(String id, {int reactions = 0, DateTime? createdAt}) {
  final pubkey = NostrPublicKey.fromHex(id.hashCode.toRadixString(16).padLeft(64, '0'));
  return Story(
    id: id,
    kind: Story.kTextNote,
    author: Author.unknown(pubkey, npub: 'npub1$id'),
    content: 'content $id',
    createdAt: createdAt ?? DateTime.utc(2026, 8, 23),
    engagement: EngagementCounts(reactions: reactions),
  );
}

void main() {
  final viewer = NostrPublicKey.fromHex('f' * 64);
  final now = DateTime.utc(2026, 8, 23, 12);

  test('fetches from the personal network provider for the resolved window', () async {
    final feed = _FakeFeedProvider()..personalNetworkStories = [_story('a', reactions: 10)];
    final generate = GenerateEdition(feed);

    final edition = await generate(
      viewer: viewer,
      configuration: const FilterConfiguration(
        source: EditionSource.personalNetwork,
        timeWindow: EditionTimeWindow.twentyFourHours,
      ),
      generateId: () => 'edition-1',
      now: now,
    );

    expect(edition.id, 'edition-1');
    expect(edition.windowEnd, now);
    expect(edition.windowStart, now.subtract(const Duration(hours: 24)));
    expect(feed.lastPersonalNetworkWindow!.since, edition.windowStart);
    expect(edition.stories.map((s) => s.id), ['a']);
  });

  test('routes to the trending provider when the source is trending', () async {
    final feed = _FakeFeedProvider()..trendingStories = [_story('t', reactions: 3)];
    final generate = GenerateEdition(feed);

    final edition = await generate(
      viewer: viewer,
      configuration: const FilterConfiguration(
        source: EditionSource.trending,
        timeWindow: EditionTimeWindow.fourHours,
      ),
      generateId: () => 'edition-2',
      now: now,
    );

    expect(edition.source, EditionSource.trending);
    expect(edition.stories.map((s) => s.id), ['t']);
  });

  test('routes to the Web of Trust provider when the source is webOfTrust', () async {
    final feed = _FakeFeedProvider()..webOfTrustStories = [_story('w', reactions: 3)];
    final generate = GenerateEdition(feed);

    final edition = await generate(
      viewer: viewer,
      configuration: const FilterConfiguration(
        source: EditionSource.webOfTrust,
        timeWindow: EditionTimeWindow.fourHours,
      ),
      generateId: () => 'edition-wot',
      now: now,
    );

    expect(edition.source, EditionSource.webOfTrust);
    expect(edition.stories.map((s) => s.id), ['w']);
  });

  test(
    'Web of Trust gets no engagement grace period, same as trending — '
    'a fresh low-engagement story is still dropped',
    () async {
      final feed = _FakeFeedProvider()
        ..webOfTrustStories = [
          _story('fresh-wot', reactions: 0, createdAt: now.subtract(const Duration(minutes: 5))),
        ];
      final generate = GenerateEdition(feed);

      final edition = await generate(
        viewer: viewer,
        configuration: const FilterConfiguration(
          source: EditionSource.webOfTrust,
          timeWindow: EditionTimeWindow.fourHours,
          thresholds: EngagementThresholds(minReactions: 10),
        ),
        generateId: () => 'edition-wot-grace',
        now: now,
      );

      expect(edition.isEmpty, isTrue);
    },
  );

  test('deduplicates stories the provider returned more than once', () async {
    final duplicate = _story('dup', reactions: 5);
    final feed = _FakeFeedProvider()..personalNetworkStories = [duplicate, duplicate, duplicate];
    final generate = GenerateEdition(feed);

    final edition = await generate(
      viewer: viewer,
      configuration: const FilterConfiguration(
        source: EditionSource.personalNetwork,
        timeWindow: EditionTimeWindow.twentyFourHours,
      ),
      generateId: () => 'edition-3',
      now: now,
    );

    expect(edition.storyCount, 1);
  });

  test('drops stories that do not meet the configured thresholds', () async {
    final feed = _FakeFeedProvider()
      ..personalNetworkStories = [
        _story('below', reactions: 2),
        _story('above', reactions: 20),
      ];
    final generate = GenerateEdition(feed);

    final edition = await generate(
      viewer: viewer,
      configuration: const FilterConfiguration(
        source: EditionSource.personalNetwork,
        timeWindow: EditionTimeWindow.twentyFourHours,
        thresholds: EngagementThresholds(minReactions: 10),
      ),
      generateId: () => 'edition-4',
      now: now,
    );

    expect(edition.stories.map((s) => s.id), ['above']);
  });

  group('engagement grace period (non-trending sources only)', () {
    test('a story younger than the grace period qualifies despite low engagement', () async {
      final feed = _FakeFeedProvider()
        ..personalNetworkStories = [
          _story('fresh', reactions: 0, createdAt: now.subtract(const Duration(minutes: 20))),
        ];
      final generate = GenerateEdition(feed);

      final edition = await generate(
        viewer: viewer,
        configuration: const FilterConfiguration(
          source: EditionSource.personalNetwork,
          timeWindow: EditionTimeWindow.twentyFourHours,
          thresholds: EngagementThresholds(minReactions: 10),
        ),
        generateId: () => 'edition-grace-1',
        now: now,
      );

      expect(edition.stories.map((s) => s.id), ['fresh']);
    });

    test('a story older than the grace period with low engagement is still dropped', () async {
      final feed = _FakeFeedProvider()
        ..personalNetworkStories = [
          _story('stale', reactions: 0, createdAt: now.subtract(const Duration(hours: 2))),
        ];
      final generate = GenerateEdition(feed);

      final edition = await generate(
        viewer: viewer,
        configuration: const FilterConfiguration(
          source: EditionSource.personalNetwork,
          timeWindow: EditionTimeWindow.twentyFourHours,
          thresholds: EngagementThresholds(minReactions: 10),
        ),
        generateId: () => 'edition-grace-2',
        now: now,
      );

      expect(edition.isEmpty, isTrue);
    });

    test('does not apply to trending — a fresh low-engagement story is still dropped', () async {
      final feed = _FakeFeedProvider()
        ..trendingStories = [
          _story('fresh-trending', reactions: 0, createdAt: now.subtract(const Duration(minutes: 5))),
        ];
      final generate = GenerateEdition(feed);

      final edition = await generate(
        viewer: viewer,
        configuration: const FilterConfiguration(
          source: EditionSource.trending,
          timeWindow: EditionTimeWindow.fourHours,
          thresholds: EngagementThresholds(minReactions: 10),
        ),
        generateId: () => 'edition-grace-3',
        now: now,
      );

      expect(edition.isEmpty, isTrue);
    });
  });

  test('routes to fetchStoriesFromList with the configured list id when source is customList', () async {
    final feed = _FakeFeedProvider()..listStories = [_story('l', reactions: 4)];
    final generate = GenerateEdition(feed);

    final edition = await generate(
      viewer: viewer,
      configuration: const FilterConfiguration(
        source: EditionSource.customList,
        timeWindow: EditionTimeWindow.twentyFourHours,
        customListId: 'bitcoin-devs',
      ),
      generateId: () => 'edition-6',
      now: now,
    );

    expect(feed.lastRequestedListId, 'bitcoin-devs');
    expect(edition.source, EditionSource.customList);
    expect(edition.stories.map((s) => s.id), ['l']);
  });

  test('customList without a customListId is a programmer error, not a silent no-op', () async {
    final feed = _FakeFeedProvider();
    final generate = GenerateEdition(feed);

    expect(
      () => generate(
        viewer: viewer,
        configuration: const FilterConfiguration(
          source: EditionSource.customList,
          timeWindow: EditionTimeWindow.twentyFourHours,
        ),
        generateId: () => 'edition-7',
        now: now,
      ),
      throwsArgumentError,
    );
  });

  test('an edition with no qualifying stories has no sections', () async {
    final feed = _FakeFeedProvider();
    final generate = GenerateEdition(feed);

    final edition = await generate(
      viewer: viewer,
      configuration: const FilterConfiguration(
        source: EditionSource.personalNetwork,
        timeWindow: EditionTimeWindow.twentyFourHours,
      ),
      generateId: () => 'edition-5',
      now: now,
    );

    expect(edition.isEmpty, isTrue);
  });
}
