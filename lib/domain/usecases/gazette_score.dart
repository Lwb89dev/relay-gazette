import 'dart:math';

import '../entities/edition_source.dart';
import '../entities/engagement.dart';
import '../entities/story.dart';

/// Every coefficient `gazetteScore` uses, gathered in one place so the
/// ranking is inspectable and adjustable rather than a black box — per the
/// product brief: "the scoring components must be understandable,
/// configurable, testable, documented."
class GazetteScoreWeights {
  /// Points per reaction.
  final double reactionWeight;

  /// Points per reply — weighted above a reaction because replying takes
  /// more effort than reacting.
  final double replyWeight;

  /// Points per repost — same reasoning as replies.
  final double repostWeight;

  /// Points per log2(sats-zapped + 1). Logarithmic so one very large zap
  /// can't single-handedly dominate the score the way linear sats would.
  final double zapWeight;

  /// How heavily "engagement per hour since publication" counts, on top of
  /// raw engagement. Rewards a note that is gaining traction fast, not just
  /// one that has accumulated a lot of engagement over a long time.
  final double velocityWeight;

  /// How heavily recency alone counts, decaying by half every
  /// [recencyHalfLife]. Keeps very old notes from crowding out today's
  /// stories purely because they had more time to accumulate engagement.
  final double recencyWeight;
  final Duration recencyHalfLife;

  /// Flat bonus added when the story comes from the reader's own network
  /// rather than global discovery. A stand-in for true social-graph
  /// distance (see the class doc comment's "known limitation").
  final double networkProximityBonus;

  const GazetteScoreWeights({
    this.reactionWeight = 1.0,
    this.replyWeight = 2.0,
    this.repostWeight = 2.0,
    this.zapWeight = 3.0,
    this.velocityWeight = 4.0,
    this.recencyWeight = 6.0,
    this.recencyHalfLife = const Duration(hours: 12),
    this.networkProximityBonus = 5.0,
  });
}

/// A breakdown of one [gazetteScore] computation, so the ranking can be
/// explained rather than just produced — e.g. for a future "why is this
/// here" affordance in the reader UI.
class GazetteScoreExplanation {
  final double engagementSignal;
  final double velocitySignal;
  final double recencySignal;
  final double proximityBonus;
  final double total;

  const GazetteScoreExplanation({
    required this.engagementSignal,
    required this.velocitySignal,
    required this.recencySignal,
    required this.proximityBonus,
    required this.total,
  });
}

/// Known limitations (documented rather than silently shipped):
///
/// - **No per-account normalization.** The brief notes "20 reactions on a
///   small account may represent a stronger signal than 40 on a huge
///   account" — doing that requires knowing each author's follower count,
///   which isn't collected anywhere in the app yet (it would mean an extra
///   query per candidate author). [reactionSignal] is therefore absolute,
///   not relative to audience size.
/// - **Social proximity is binary, not graph distance.** True "how close
///   is this author in my social graph" would need second-degree follow
///   data (the brief allows this: "optionally second-degree social graph
///   content"). What's implemented is a coarser proxy: a flat bonus for
///   personal-network stories vs. none for trending/discovery ones, since
///   [Story] doesn't carry graph-distance metadata.
///
/// Both are natural follow-ups once the underlying data is being
/// collected; nothing here would need to change shape to add them — they
/// slot in as extra terms alongside `engagementSignal`.
GazetteScoreExplanation explainGazetteScore(
  Story story, {
  required EditionSource source,
  required DateTime now,
  GazetteScoreWeights weights = const GazetteScoreWeights(),
}) {
  final EngagementCounts counts = story.engagement;
  final zapSignal = counts.zapSats > 0 ? log(counts.zapSats + 1) / ln2 : 0.0;
  final engagementSignal =
      counts.reactions * weights.reactionWeight +
      counts.replies * weights.replyWeight +
      counts.reposts * weights.repostWeight +
      zapSignal * weights.zapWeight;

  final ageHours = max(
    now.difference(story.createdAt).inSeconds / 3600.0,
    1 / 60,
  );
  final velocitySignal = (engagementSignal / ageHours) * weights.velocityWeight;

  final halfLifeHours = max(weights.recencyHalfLife.inMinutes / 60.0, 1 / 60);
  final recencySignal =
      pow(0.5, ageHours / halfLifeHours).toDouble() * weights.recencyWeight;

  final proximityBonus = source == EditionSource.personalNetwork
      ? weights.networkProximityBonus
      : 0.0;

  return GazetteScoreExplanation(
    engagementSignal: engagementSignal,
    velocitySignal: velocitySignal,
    recencySignal: recencySignal,
    proximityBonus: proximityBonus,
    total: engagementSignal + velocitySignal + recencySignal + proximityBonus,
  );
}

double gazetteScore(
  Story story, {
  required EditionSource source,
  required DateTime now,
  GazetteScoreWeights weights = const GazetteScoreWeights(),
}) {
  return explainGazetteScore(
    story,
    source: source,
    now: now,
    weights: weights,
  ).total;
}
