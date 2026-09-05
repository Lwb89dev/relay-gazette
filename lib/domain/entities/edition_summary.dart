import 'edition_source.dart';

/// Lightweight listing row for the edition archive — enough to render
/// "Today / Yesterday / Aug 21" shelves without decoding a full edition's
/// stories from storage.
class GazetteEditionSummary {
  final String id;
  final DateTime generatedAt;
  final DateTime windowStart;
  final DateTime windowEnd;
  final EditionSource source;
  final int storyCount;

  const GazetteEditionSummary({
    required this.id,
    required this.generatedAt,
    required this.windowStart,
    required this.windowEnd,
    required this.source,
    required this.storyCount,
  });
}
