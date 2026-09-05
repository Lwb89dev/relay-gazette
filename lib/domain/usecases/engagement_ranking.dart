import 'dart:math';

import '../entities/engagement.dart';

/// A small, fully transparent weighting used only to order stories inside
/// a section (e.g. which qualifying story leads "Top Stories"). This is
/// deliberately not the "GazetteScore" described in the product brief —
/// that is a larger, normalized, socially-weighted ranking system reserved
/// for a later phase. This function exists so an edition has *some*
/// deterministic order beyond raw chronology, and every term is a plain,
/// documented count:
///
/// - each reaction counts once;
/// - a reply or repost counts double, since both require more effort than a
///   reaction and are stronger signals of engagement;
/// - zap sats are weighted logarithmically so a single large zap can't
///   dominate the ordering the way it would under linear weighting.
int engagementWeight(EngagementCounts counts) {
  final zapWeight = counts.zapSats > 0
      ? (log(counts.zapSats + 1) / ln2 * 3).round()
      : 0;
  return counts.reactions +
      (counts.replies * 2) +
      (counts.reposts * 2) +
      zapWeight;
}
