import 'edition_source.dart';
import 'engagement.dart';
import 'time_window.dart';

/// Everything the reader chose before generating an edition. Stored
/// verbatim on the resulting [GazetteEdition] so a past edition can explain
/// why it contains what it contains.
class FilterConfiguration {
  final EditionSource source;
  final EditionTimeWindow timeWindow;
  final EngagementThresholds thresholds;

  /// The NIP-51 list id to draw authors from. Required when [source] is
  /// [EditionSource.customList]; ignored otherwise.
  final String? customListId;

  const FilterConfiguration({
    required this.source,
    required this.timeWindow,
    this.thresholds = EngagementThresholds.none,
    this.customListId,
  });
}
