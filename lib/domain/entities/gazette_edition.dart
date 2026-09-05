import 'edition_section.dart';
import 'edition_source.dart';
import 'filter_configuration.dart';
import 'story.dart';

/// A finished, immutable snapshot of a newspaper edition. Once generated,
/// this is what gets persisted and read — it is never re-fetched or
/// re-ranked live. See ARCHITECTURE.md, "The Edition Model".
class GazetteEdition {
  final String id;
  final DateTime generatedAt;
  final DateTime windowStart;
  final DateTime windowEnd;
  final EditionSource source;
  final FilterConfiguration filterConfiguration;
  final List<EditionSection> sections;

  const GazetteEdition({
    required this.id,
    required this.generatedAt,
    required this.windowStart,
    required this.windowEnd,
    required this.source,
    required this.filterConfiguration,
    required this.sections,
  });

  List<Story> get stories => sections.expand((s) => s.stories).toList();

  int get storyCount => stories.length;

  bool get isEmpty => sections.every((s) => s.isEmpty);
}
