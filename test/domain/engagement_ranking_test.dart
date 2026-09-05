import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/domain/entities/engagement.dart';
import 'package:relay_gazette/domain/usecases/engagement_ranking.dart';

void main() {
  test('zero engagement weighs zero', () {
    expect(engagementWeight(EngagementCounts.zero), 0);
  });

  test('reactions weigh one point each', () {
    expect(engagementWeight(const EngagementCounts(reactions: 7)), 7);
  });

  test('replies and reposts weigh double a reaction', () {
    expect(engagementWeight(const EngagementCounts(replies: 3)), 6);
    expect(engagementWeight(const EngagementCounts(reposts: 3)), 6);
  });

  test('a single huge zap does not linearly dominate the score', () {
    final small = engagementWeight(const EngagementCounts(zapSats: 100));
    final huge = engagementWeight(const EngagementCounts(zapSats: 1000000));
    // Logarithmic weighting: 10,000x more sats should not mean 10,000x the score.
    expect(huge, lessThan(small * 100));
  });

  test('more zap sats never scores lower than fewer zap sats', () {
    final low = engagementWeight(const EngagementCounts(zapSats: 500));
    final high = engagementWeight(const EngagementCounts(zapSats: 5000));
    expect(high, greaterThanOrEqualTo(low));
  });

  test('weight is the sum of all signal contributions', () {
    const counts = EngagementCounts(reactions: 10, replies: 2, reposts: 1, zapSats: 0);
    expect(engagementWeight(counts), 10 + 2 * 2 + 1 * 2);
  });
}
