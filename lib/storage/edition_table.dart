import 'package:drift/drift.dart';

/// Persisted editions. Sections/stories are stored as a single JSON blob
/// rather than normalized across many tables: an edition is always read (and
/// written) as one atomic snapshot, never queried story-by-story, so the
/// relational overhead of full normalization wouldn't buy anything today.
/// The indexed scalar columns exist purely so the archive shelf can list
/// editions without decoding every payload. Revisit if a future feature
/// (e.g. a cross-edition saved reading list) needs to query into stories.
class Editions extends Table {
  TextColumn get id => text()();
  IntColumn get generatedAtUtcMillis => integer()();
  IntColumn get windowStartUtcMillis => integer()();
  IntColumn get windowEndUtcMillis => integer()();
  TextColumn get source => text()();
  IntColumn get storyCount => integer()();
  TextColumn get payloadJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}
