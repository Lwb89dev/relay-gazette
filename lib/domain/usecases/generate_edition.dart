import '../entities/edition_source.dart';
import '../entities/filter_configuration.dart';
import '../entities/gazette_edition.dart';
import '../entities/nostr_public_key.dart';
import '../entities/story.dart';
import '../repositories/feed_provider.dart';
import 'build_edition_sections.dart';

/// Orchestrates turning a reader's chosen [FilterConfiguration] into a
/// finished [GazetteEdition]: fetch, dedupe, threshold-filter, section.
/// The result is a plain snapshot — nothing here keeps a live connection
/// open, and nothing about relays or Primal leaks past [FeedProvider].
class GenerateEdition {
  /// A story younger than this, in a followed/curated feed, qualifies
  /// regardless of its engagement thresholds. Engagement accumulates over
  /// time, so a post from minutes ago is compared unfairly against one from
  /// hours ago in the same window — this stops that from meaning "posted
  /// recently" quietly loses to "posted earlier today". Doesn't apply to
  /// trending or Web of Trust: for both, a story's whole reason for being a
  /// candidate *is* engagement Primal already measured server-side — there's
  /// no "give it more time" grace to extend on top of that.
  static const engagementGracePeriod = Duration(hours: 1);

  /// Discovery sources: the candidate pool itself is already engagement-
  /// ranked by a server (Primal), unlike a reader's own curated feed.
  static const _discoverySources = {EditionSource.trending, EditionSource.webOfTrust};

  final FeedProvider _feedProvider;
  final BuildEditionSections _sectionBuilder;

  const GenerateEdition(
    this._feedProvider, {
    this._sectionBuilder = const BuildEditionSections(),
  });

  Future<GazetteEdition> call({
    required NostrPublicKey viewer,
    required FilterConfiguration configuration,
    required String Function() generateId,
    DateTime? now,
  }) async {
    final window = configuration.timeWindow.resolve(now: now);
    final rawStories = await _fetchRawStories(viewer, configuration, window);

    final qualifying = _dedupe(rawStories)
        .where((story) => _qualifies(story, configuration, window.end))
        .toList();

    final sections = _sectionBuilder(
      source: configuration.source,
      qualifyingStories: qualifying,
    );

    return GazetteEdition(
      id: generateId(),
      generatedAt: (now ?? DateTime.now()).toUtc(),
      windowStart: window.start,
      windowEnd: window.end,
      source: configuration.source,
      filterConfiguration: configuration,
      sections: sections,
    );
  }

  Future<List<Story>> _fetchRawStories(
    NostrPublicKey viewer,
    FilterConfiguration configuration,
    ({DateTime start, DateTime end}) window,
  ) {
    return switch (configuration.source) {
      EditionSource.trending => _feedProvider.fetchTrendingStories(since: window.start, until: window.end),
      EditionSource.webOfTrust => _feedProvider.fetchWebOfTrustStories(
          pubkey: viewer,
          since: window.start,
          until: window.end,
        ),
      EditionSource.personalNetwork => _feedProvider.fetchPersonalNetworkStories(
          pubkey: viewer,
          since: window.start,
          until: window.end,
        ),
      EditionSource.customList => _feedProvider.fetchStoriesFromList(
          owner: viewer,
          listId: configuration.customListId ??
              (throw ArgumentError('customListId is required when source is customList')),
          since: window.start,
          until: window.end,
        ),
    };
  }

  bool _qualifies(Story story, FilterConfiguration configuration, DateTime generatedAt) {
    if (configuration.thresholds.isSatisfiedBy(story.engagement)) return true;
    if (_discoverySources.contains(configuration.source)) return false;
    return generatedAt.difference(story.createdAt) <= engagementGracePeriod;
  }

  /// Relays commonly deliver the same event more than once (fan-out across
  /// multiple connections); a provider fetching from several sources at
  /// once makes this worse. Dedupe by event id, keeping the first copy seen.
  List<Story> _dedupe(List<Story> stories) {
    final byId = <String, Story>{};
    for (final story in stories) {
      byId.putIfAbsent(story.id, () => story);
    }
    return byId.values.toList();
  }
}
