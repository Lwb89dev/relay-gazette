import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';

void main() {
  test('no thresholds are satisfied by anything, including zero engagement', () {
    expect(EngagementThresholds.none.isSatisfiedBy(EngagementCounts.zero), isTrue);
  });

  test('a story exactly at the minimum reaction count qualifies', () {
    const thresholds = EngagementThresholds(minReactions: 10);
    expect(thresholds.isSatisfiedBy(const EngagementCounts(reactions: 10)), isTrue);
    expect(thresholds.isSatisfiedBy(const EngagementCounts(reactions: 9)), isFalse);
  });

  test('multiple thresholds must all be satisfied', () {
    const thresholds = EngagementThresholds(minReactions: 5, minReplies: 2);
    expect(
      thresholds.isSatisfiedBy(const EngagementCounts(reactions: 5, replies: 2)),
      isTrue,
    );
    expect(
      thresholds.isSatisfiedBy(const EngagementCounts(reactions: 5, replies: 1)),
      isFalse,
    );
    expect(
      thresholds.isSatisfiedBy(const EngagementCounts(reactions: 4, replies: 2)),
      isFalse,
    );
  });

  test('zap thresholds check count and sats independently', () {
    const thresholds = EngagementThresholds(minZaps: 3, minSatsReceived: 1000);
    expect(
      thresholds.isSatisfiedBy(const EngagementCounts(zapCount: 3, zapSats: 999)),
      isFalse,
    );
    expect(
      thresholds.isSatisfiedBy(const EngagementCounts(zapCount: 2, zapSats: 1000)),
      isFalse,
    );
    expect(
      thresholds.isSatisfiedBy(const EngagementCounts(zapCount: 3, zapSats: 1000)),
      isTrue,
    );
  });

  test('isEmpty reports whether any threshold is set', () {
    expect(EngagementThresholds.none.isEmpty, isTrue);
    expect(const EngagementThresholds(minReactions: 1).isEmpty, isFalse);
  });
}
