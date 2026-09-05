import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/entities/edition_source.dart';
import '../../domain/entities/edition_summary.dart';
import '../../domain/entities/gazette_edition.dart';
import '../../domain/repositories/edition_repository.dart';
import '../../storage/database.dart';
import 'edition_codec.dart';

class EditionRepositoryImpl implements EditionRepository {
  final AppDatabase _db;
  final EditionCodec _codec;

  EditionRepositoryImpl(this._db, {this._codec = const EditionCodec()});

  @override
  Future<void> save(GazetteEdition edition) async {
    final payload = jsonEncode(_codec.encodePayload(edition));
    await _db
        .into(_db.editions)
        .insertOnConflictUpdate(
          EditionsCompanion.insert(
            id: edition.id,
            generatedAtUtcMillis: edition.generatedAt.millisecondsSinceEpoch,
            windowStartUtcMillis: edition.windowStart.millisecondsSinceEpoch,
            windowEndUtcMillis: edition.windowEnd.millisecondsSinceEpoch,
            source: edition.source.name,
            storyCount: edition.storyCount,
            payloadJson: payload,
          ),
        );
  }

  @override
  Future<GazetteEdition?> getById(String id) async {
    final row = await (_db.select(
      _db.editions,
    )..where((e) => e.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return _codec.decode(
      id: row.id,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.generatedAtUtcMillis,
        isUtc: true,
      ),
      windowStart: DateTime.fromMillisecondsSinceEpoch(
        row.windowStartUtcMillis,
        isUtc: true,
      ),
      windowEnd: DateTime.fromMillisecondsSinceEpoch(
        row.windowEndUtcMillis,
        isUtc: true,
      ),
      source: EditionSource.values.byName(row.source),
      payload: jsonDecode(row.payloadJson) as Map<String, dynamic>,
    );
  }

  @override
  Future<List<GazetteEditionSummary>> getAllSummaries() async {
    final rows = await (_db.select(
      _db.editions,
    )..orderBy([(e) => OrderingTerm.desc(e.generatedAtUtcMillis)])).get();
    return rows
        .map(
          (row) => GazetteEditionSummary(
            id: row.id,
            generatedAt: DateTime.fromMillisecondsSinceEpoch(
              row.generatedAtUtcMillis,
              isUtc: true,
            ),
            windowStart: DateTime.fromMillisecondsSinceEpoch(
              row.windowStartUtcMillis,
              isUtc: true,
            ),
            windowEnd: DateTime.fromMillisecondsSinceEpoch(
              row.windowEndUtcMillis,
              isUtc: true,
            ),
            source: EditionSource.values.byName(row.source),
            storyCount: row.storyCount,
          ),
        )
        .toList();
  }

  @override
  Future<void> delete(String id) async {
    await (_db.delete(_db.editions)..where((e) => e.id.equals(id))).go();
  }
}
