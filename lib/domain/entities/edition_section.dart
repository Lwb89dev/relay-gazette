import 'story.dart';

/// One editorial section of an edition (e.g. "Top Stories", "From Your
/// Network"). Sections are optional and pluggable — an edition only
/// contains the sections its configuration actually produced content for.
class EditionSection {
  final String id;
  final String title;
  final List<Story> stories;

  const EditionSection({
    required this.id,
    required this.title,
    required this.stories,
  });

  bool get isEmpty => stories.isEmpty;
}
