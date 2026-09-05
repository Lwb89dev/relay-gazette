import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay_gazette/data/editions/edition_repository_impl.dart';
import 'package:relay_gazette/domain/entities/edition_section.dart';
import 'package:relay_gazette/domain/entities/edition_source.dart';
import 'package:relay_gazette/domain/entities/filter_configuration.dart';
import 'package:relay_gazette/domain/entities/gazette_edition.dart';
import 'package:relay_gazette/domain/entities/time_window.dart';
import 'package:relay_gazette/storage/database.dart';

GazetteEdition _edition(String id, {DateTime? generatedAt, List<EditionSection> sections = const []}) {
  final at = generatedAt ?? DateTime.utc(2026, 8, 23);
  return GazetteEdition(
    id: id,
    generatedAt: at,
    windowStart: at.subtract(const Duration(hours: 24)),
    windowEnd: at,
    source: EditionSource.personalNetwork,
    filterConfiguration: const FilterConfiguration(
      source: EditionSource.personalNetwork,
      timeWindow: EditionTimeWindow.twentyFourHours,
    ),
    sections: sections,
  );
}

void main() {
  late AppDatabase db;
  late EditionRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = EditionRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('save then getById returns an equivalent edition', () async {
    final edition = _edition('e1');
    await repository.save(edition);

    final loaded = await repository.getById('e1');

    expect(loaded, isNotNull);
    expect(loaded!.id, 'e1');
    expect(loaded.windowStart, edition.windowStart);
    expect(loaded.source, EditionSource.personalNetwork);
  });

  test('getById returns null for an unknown id', () async {
    expect(await repository.getById('missing'), isNull);
  });

  test('save is idempotent for the same id (upsert, not duplicate rows)', () async {
    await repository.save(_edition('e1'));
    await repository.save(_edition('e1'));

    final summaries = await repository.getAllSummaries();
    expect(summaries.where((s) => s.id == 'e1'), hasLength(1));
  });

  test('getAllSummaries lists editions newest-first', () async {
    await repository.save(_edition('older', generatedAt: DateTime.utc(2026, 8, 20)));
    await repository.save(_edition('newer', generatedAt: DateTime.utc(2026, 8, 23)));

    final summaries = await repository.getAllSummaries();

    expect(summaries.map((s) => s.id), ['newer', 'older']);
  });

  test('delete removes an edition', () async {
    await repository.save(_edition('e1'));
    await repository.delete('e1');

    expect(await repository.getById('e1'), isNull);
    expect(await repository.getAllSummaries(), isEmpty);
  });
}
