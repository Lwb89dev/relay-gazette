/// Raw engagement signals collected for a single story. Deliberately plain
/// counters — no scoring here, see `engagement_ranking.dart` for that.
class EngagementCounts {
  final int reactions;
  final int replies;
  final int reposts;
  final int zapCount;
  final int zapSats;

  const EngagementCounts({
    this.reactions = 0,
    this.replies = 0,
    this.reposts = 0,
    this.zapCount = 0,
    this.zapSats = 0,
  });

  static const zero = EngagementCounts();

  EngagementCounts copyWith({
    int? reactions,
    int? replies,
    int? reposts,
    int? zapCount,
    int? zapSats,
  }) {
    return EngagementCounts(
      reactions: reactions ?? this.reactions,
      replies: replies ?? this.replies,
      reposts: reposts ?? this.reposts,
      zapCount: zapCount ?? this.zapCount,
      zapSats: zapSats ?? this.zapSats,
    );
  }
}

/// Deterministic, user-configurable minimums a story must clear to qualify
/// for an edition. Every field is optional: an unset threshold imposes no
/// requirement. This is intentionally simple and explainable — the
/// alternative (an opaque ranking algorithm) is what the product explicitly
/// avoids forcing on the reader.
class EngagementThresholds {
  final int? minReactions;
  final int? minReplies;
  final int? minReposts;
  final int? minZaps;
  final int? minSatsReceived;

  const EngagementThresholds({
    this.minReactions,
    this.minReplies,
    this.minReposts,
    this.minZaps,
    this.minSatsReceived,
  });

  static const none = EngagementThresholds();

  bool isSatisfiedBy(EngagementCounts counts) {
    if (minReactions != null && counts.reactions < minReactions!) return false;
    if (minReplies != null && counts.replies < minReplies!) return false;
    if (minReposts != null && counts.reposts < minReposts!) return false;
    if (minZaps != null && counts.zapCount < minZaps!) return false;
    if (minSatsReceived != null && counts.zapSats < minSatsReceived!)
      return false;
    return true;
  }

  bool get isEmpty =>
      minReactions == null &&
      minReplies == null &&
      minReposts == null &&
      minZaps == null &&
      minSatsReceived == null;
}
