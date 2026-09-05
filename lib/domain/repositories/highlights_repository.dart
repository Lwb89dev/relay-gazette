import '../entities/highlight.dart';

/// Reads NIP-84 highlights other readers (or this one, on a past visit)
/// have left on a story. Kept separate from [FeedProvider] since it's a
/// different concern — reading annotations on a story, not fetching
/// stories themselves.
abstract class HighlightsRepository {
  Future<List<Highlight>> fetchHighlights(String storyEventId);
}
