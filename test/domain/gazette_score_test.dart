import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/author.dart';
import 'package:relay_gazette/domain/entities/edition_source.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/entities/nostr_public_key.dart';
import 'package:relay_gazette/domain/entities/story.dart';
import 'package:relay_gazette/domain/usecases/gazette_score.dart';

Story _story({
  EngagementCounts engagement = EngagementCounts.zero,
  required DateTime createdAt,
}) {
  final pubkey = NostrPublicKey.fromHex('a' * 64);
  return Story(
    id: 'note',
    kind: Story.kTextNote,
    author: Author.unknown(pubkey, npub: 'npub1author'),
    content: 'content',
    createdAt: createdAt,
    engagement: engagement,
  );
}

void main() {
  final now = DateTime.utc(2026, 8, 23, 12);

  test('a brand-new story with zero engagement still scores above zero from recency alone', () {
    final story = _story(createdAt: now);
    final score = gazetteScore(story, source: EditionSource.trending, now: now);
    expect(score, greaterThan(0));
  });

  test('more reactions score strictly higher, all else equal', () {
    final few = _story(engagement: const EngagementCounts(reactions: 2), createdAt: now);
    final many = _story(engagement: const EngagementCounts(reactions: 20), createdAt: now);

    final scoreFew = gazetteScore(few, source: EditionSource.trending, now: now);
    final scoreMany = gazetteScore(many, source: EditionSource.trending, now: now);

    expect(scoreMany, greaterThan(scoreFew));
  });

  test('zap sats are weighted logarithmically, not linearly', () {
    final small = _story(engagement: const EngagementCounts(zapSats: 100), createdAt: now);
    final huge = _story(engagement: const EngagementCounts(zapSats: 1000000), createdAt: now);

    final scoreSmall = gazetteScore(small, source: EditionSource.trending, now: now);
    final scoreHuge = gazetteScore(huge, source: EditionSource.trending, now: now);

    // 10,000x the sats should come nowhere near 10,000x the score.
    expect(scoreHuge, lessThan(scoreSmall * 100));
    expect(scoreHuge, greaterThan(scoreSmall));
  });

  test('an older story with identical engagement scores lower (recency decay)', () {
    final recent = _story(
      engagement: const EngagementCounts(reactions: 10),
      createdAt: now.subtract(const Duration(hours: 1)),
    );
    final old = _story(
      engagement: const EngagementCounts(reactions: 10),
      createdAt: now.subtract(const Duration(hours: 48)),
    );

    final scoreRecent = gazetteScore(recent, source: EditionSource.trending, now: now);
    final scoreOld = gazetteScore(old, source: EditionSource.trending, now: now);

    expect(scoreRecent, greaterThan(scoreOld));
  });

  test('the same engagement gained faster (younger story) scores higher on velocity', () {
    final fast = _story(
      engagement: const EngagementCounts(reactions: 20),
      createdAt: now.subtract(const Duration(hours: 1)),
    );
    final slow = _story(
      engagement: const EngagementCounts(reactions: 20),
      createdAt: now.subtract(const Duration(hours: 10)),
    );

    final explainFast = explainGazetteScore(fast, source: EditionSource.trending, now: now);
    final explainSlow = explainGazetteScore(slow, source: EditionSource.trending, now: now);

    expect(explainFast.engagementSignal, explainSlow.engagementSignal); // same raw engagement
    expect(explainFast.velocitySignal, greaterThan(explainSlow.velocitySignal));
  });

  test('personal-network stories get a proximity bonus that trending stories do not', () {
    final story = _story(createdAt: now);

    final networkScore = gazetteScore(story, source: EditionSource.personalNetwork, now: now);
    final trendingScore = gazetteScore(story, source: EditionSource.trending, now: now);

    expect(networkScore, greaterThan(trendingScore));
  });

  test('custom weights change the outcome predictably: zeroing zapWeight removes its contribution', () {
    final story = _story(engagement: const EngagementCounts(zapSats: 5000), createdAt: now);

    const zeroedZap = GazetteScoreWeights(zapWeight: 0, velocityWeight: 0);
    final explanation = explainGazetteScore(story, source: EditionSource.trending, now: now, weights: zeroedZap);

    expect(explanation.engagementSignal, 0);
  });

  test('explanation components sum exactly to the total', () {
    final story = _story(
      engagement: const EngagementCounts(reactions: 5, replies: 2, reposts: 1, zapSats: 210),
      createdAt: now.subtract(const Duration(hours: 3)),
    );

    final explanation = explainGazetteScore(story, source: EditionSource.personalNetwork, now: now);

    expect(
      explanation.total,
      closeTo(
        explanation.engagementSignal +
            explanation.velocitySignal +
            explanation.recencySignal +
            explanation.proximityBonus,
        1e-9,
      ),
    );
  });

  test('is deterministic: same inputs always produce the same score', () {
    final story = _story(engagement: const EngagementCounts(reactions: 7), createdAt: now);
    final a = gazetteScore(story, source: EditionSource.trending, now: now);
    final b = gazetteScore(story, source: EditionSource.trending, now: now);
    expect(a, b);
  });
}
