import '../entities/edition_section.dart';
import '../entities/edition_source.dart';
import '../entities/story.dart';
import 'engagement_ranking.dart';

/// Turns a flat list of qualifying stories into the editorial sections an
/// edition is made of. Sections are additive and optional: a section is
/// only emitted when it actually has stories, so a small edition might
/// only ever produce "Top Stories".
/// Scores a story for ordering purposes — higher sorts first. Implemented
/// by the default [engagementWeight] and, optionally, by `gazetteScore`
/// (domain/usecases/gazette_score.dart) for a richer, recency/velocity-aware
/// ranking.
typedef StoryRanker = num Function(Story story);

class BuildEditionSections {
  final int topStoriesCount;
  final StoryRanker? ranker;

  const BuildEditionSections({this.topStoriesCount = 5, this.ranker});

  List<EditionSection> call({
    required EditionSource source,
    required List<Story> qualifyingStories,
  }) {
    if (qualifyingStories.isEmpty) return const [];

    final byWeightThenRecency = [...qualifyingStories]..sort(_compare);

    // Discovery sources (trending, Web of Trust) arrive already ranked by
    // a server-side algorithm as one coherent feed — splitting that into
    // "Top Stories" vs. "everything else" would just be re-imposing a
    // structure the ranking already provided, unlike a reader's own
    // curated feed (personalNetwork/customList) where that split adds
    // real information.
    if (source == EditionSource.trending || source == EditionSource.webOfTrust) {
      return [
        EditionSection(
          id: source == EditionSource.trending ? 'trending' : 'web-of-trust',
          title: source.label,
          stories: byWeightThenRecency,
        ),
      ];
    }

    final topStories = byWeightThenRecency.take(topStoriesCount).toList();
    final topIds = topStories.map((s) => s.id).toSet();
    final remaining =
        qualifyingStories.where((s) => !topIds.contains(s.id)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return [
      if (topStories.isNotEmpty)
        EditionSection(
          id: 'top-stories',
          title: 'Top Stories',
          stories: topStories,
        ),
      if (remaining.isNotEmpty)
        EditionSection(id: 'from-your-network', title: source.label, stories: remaining),
    ];
  }

  int _compare(Story a, Story b) {
    final score = ranker ?? (Story s) => engagementWeight(s.engagement);
    final byScore = score(b).compareTo(score(a));
    if (byScore != 0) return byScore;
    return b.createdAt.compareTo(a.createdAt);
  }
}
