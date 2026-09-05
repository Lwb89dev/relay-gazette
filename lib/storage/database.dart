import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'edition_table.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Editions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'relay_gazette'));

  @override
  int get schemaVersion => 1;
}
