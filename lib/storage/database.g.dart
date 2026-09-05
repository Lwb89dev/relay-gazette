// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $EditionsTable extends Editions with TableInfo<$EditionsTable, Edition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EditionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _generatedAtUtcMillisMeta =
      const VerificationMeta('generatedAtUtcMillis');
  @override
  late final GeneratedColumn<int> generatedAtUtcMillis = GeneratedColumn<int>(
    'generated_at_utc_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowStartUtcMillisMeta =
      const VerificationMeta('windowStartUtcMillis');
  @override
  late final GeneratedColumn<int> windowStartUtcMillis = GeneratedColumn<int>(
    'window_start_utc_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowEndUtcMillisMeta =
      const VerificationMeta('windowEndUtcMillis');
  @override
  late final GeneratedColumn<int> windowEndUtcMillis = GeneratedColumn<int>(
    'window_end_utc_millis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _storyCountMeta = const VerificationMeta(
    'storyCount',
  );
  @override
  late final GeneratedColumn<int> storyCount = GeneratedColumn<int>(
    'story_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    generatedAtUtcMillis,
    windowStartUtcMillis,
    windowEndUtcMillis,
    source,
    storyCount,
    payloadJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'editions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Edition> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('generated_at_utc_millis')) {
      context.handle(
        _generatedAtUtcMillisMeta,
        generatedAtUtcMillis.isAcceptableOrUnknown(
          data['generated_at_utc_millis']!,
          _generatedAtUtcMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_generatedAtUtcMillisMeta);
    }
    if (data.containsKey('window_start_utc_millis')) {
      context.handle(
        _windowStartUtcMillisMeta,
        windowStartUtcMillis.isAcceptableOrUnknown(
          data['window_start_utc_millis']!,
          _windowStartUtcMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_windowStartUtcMillisMeta);
    }
    if (data.containsKey('window_end_utc_millis')) {
      context.handle(
        _windowEndUtcMillisMeta,
        windowEndUtcMillis.isAcceptableOrUnknown(
          data['window_end_utc_millis']!,
          _windowEndUtcMillisMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_windowEndUtcMillisMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('story_count')) {
      context.handle(
        _storyCountMeta,
        storyCount.isAcceptableOrUnknown(data['story_count']!, _storyCountMeta),
      );
    } else if (isInserting) {
      context.missing(_storyCountMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Edition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Edition(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      generatedAtUtcMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}generated_at_utc_millis'],
      )!,
      windowStartUtcMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_start_utc_millis'],
      )!,
      windowEndUtcMillis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_end_utc_millis'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      storyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}story_count'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
    );
  }

  @override
  $EditionsTable createAlias(String alias) {
    return $EditionsTable(attachedDatabase, alias);
  }
}

class Edition extends DataClass implements Insertable<Edition> {
  final String id;
  final int generatedAtUtcMillis;
  final int windowStartUtcMillis;
  final int windowEndUtcMillis;
  final String source;
  final int storyCount;
  final String payloadJson;
  const Edition({
    required this.id,
    required this.generatedAtUtcMillis,
    required this.windowStartUtcMillis,
    required this.windowEndUtcMillis,
    required this.source,
    required this.storyCount,
    required this.payloadJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['generated_at_utc_millis'] = Variable<int>(generatedAtUtcMillis);
    map['window_start_utc_millis'] = Variable<int>(windowStartUtcMillis);
    map['window_end_utc_millis'] = Variable<int>(windowEndUtcMillis);
    map['source'] = Variable<String>(source);
    map['story_count'] = Variable<int>(storyCount);
    map['payload_json'] = Variable<String>(payloadJson);
    return map;
  }

  EditionsCompanion toCompanion(bool nullToAbsent) {
    return EditionsCompanion(
      id: Value(id),
      generatedAtUtcMillis: Value(generatedAtUtcMillis),
      windowStartUtcMillis: Value(windowStartUtcMillis),
      windowEndUtcMillis: Value(windowEndUtcMillis),
      source: Value(source),
      storyCount: Value(storyCount),
      payloadJson: Value(payloadJson),
    );
  }

  factory Edition.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Edition(
      id: serializer.fromJson<String>(json['id']),
      generatedAtUtcMillis: serializer.fromJson<int>(
        json['generatedAtUtcMillis'],
      ),
      windowStartUtcMillis: serializer.fromJson<int>(
        json['windowStartUtcMillis'],
      ),
      windowEndUtcMillis: serializer.fromJson<int>(json['windowEndUtcMillis']),
      source: serializer.fromJson<String>(json['source']),
      storyCount: serializer.fromJson<int>(json['storyCount']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'generatedAtUtcMillis': serializer.toJson<int>(generatedAtUtcMillis),
      'windowStartUtcMillis': serializer.toJson<int>(windowStartUtcMillis),
      'windowEndUtcMillis': serializer.toJson<int>(windowEndUtcMillis),
      'source': serializer.toJson<String>(source),
      'storyCount': serializer.toJson<int>(storyCount),
      'payloadJson': serializer.toJson<String>(payloadJson),
    };
  }

  Edition copyWith({
    String? id,
    int? generatedAtUtcMillis,
    int? windowStartUtcMillis,
    int? windowEndUtcMillis,
    String? source,
    int? storyCount,
    String? payloadJson,
  }) => Edition(
    id: id ?? this.id,
    generatedAtUtcMillis: generatedAtUtcMillis ?? this.generatedAtUtcMillis,
    windowStartUtcMillis: windowStartUtcMillis ?? this.windowStartUtcMillis,
    windowEndUtcMillis: windowEndUtcMillis ?? this.windowEndUtcMillis,
    source: source ?? this.source,
    storyCount: storyCount ?? this.storyCount,
    payloadJson: payloadJson ?? this.payloadJson,
  );
  Edition copyWithCompanion(EditionsCompanion data) {
    return Edition(
      id: data.id.present ? data.id.value : this.id,
      generatedAtUtcMillis: data.generatedAtUtcMillis.present
          ? data.generatedAtUtcMillis.value
          : this.generatedAtUtcMillis,
      windowStartUtcMillis: data.windowStartUtcMillis.present
          ? data.windowStartUtcMillis.value
          : this.windowStartUtcMillis,
      windowEndUtcMillis: data.windowEndUtcMillis.present
          ? data.windowEndUtcMillis.value
          : this.windowEndUtcMillis,
      source: data.source.present ? data.source.value : this.source,
      storyCount: data.storyCount.present
          ? data.storyCount.value
          : this.storyCount,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Edition(')
          ..write('id: $id, ')
          ..write('generatedAtUtcMillis: $generatedAtUtcMillis, ')
          ..write('windowStartUtcMillis: $windowStartUtcMillis, ')
          ..write('windowEndUtcMillis: $windowEndUtcMillis, ')
          ..write('source: $source, ')
          ..write('storyCount: $storyCount, ')
          ..write('payloadJson: $payloadJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    generatedAtUtcMillis,
    windowStartUtcMillis,
    windowEndUtcMillis,
    source,
    storyCount,
    payloadJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Edition &&
          other.id == this.id &&
          other.generatedAtUtcMillis == this.generatedAtUtcMillis &&
          other.windowStartUtcMillis == this.windowStartUtcMillis &&
          other.windowEndUtcMillis == this.windowEndUtcMillis &&
          other.source == this.source &&
          other.storyCount == this.storyCount &&
          other.payloadJson == this.payloadJson);
}

class EditionsCompanion extends UpdateCompanion<Edition> {
  final Value<String> id;
  final Value<int> generatedAtUtcMillis;
  final Value<int> windowStartUtcMillis;
  final Value<int> windowEndUtcMillis;
  final Value<String> source;
  final Value<int> storyCount;
  final Value<String> payloadJson;
  final Value<int> rowid;
  const EditionsCompanion({
    this.id = const Value.absent(),
    this.generatedAtUtcMillis = const Value.absent(),
    this.windowStartUtcMillis = const Value.absent(),
    this.windowEndUtcMillis = const Value.absent(),
    this.source = const Value.absent(),
    this.storyCount = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EditionsCompanion.insert({
    required String id,
    required int generatedAtUtcMillis,
    required int windowStartUtcMillis,
    required int windowEndUtcMillis,
    required String source,
    required int storyCount,
    required String payloadJson,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       generatedAtUtcMillis = Value(generatedAtUtcMillis),
       windowStartUtcMillis = Value(windowStartUtcMillis),
       windowEndUtcMillis = Value(windowEndUtcMillis),
       source = Value(source),
       storyCount = Value(storyCount),
       payloadJson = Value(payloadJson);
  static Insertable<Edition> custom({
    Expression<String>? id,
    Expression<int>? generatedAtUtcMillis,
    Expression<int>? windowStartUtcMillis,
    Expression<int>? windowEndUtcMillis,
    Expression<String>? source,
    Expression<int>? storyCount,
    Expression<String>? payloadJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (generatedAtUtcMillis != null)
        'generated_at_utc_millis': generatedAtUtcMillis,
      if (windowStartUtcMillis != null)
        'window_start_utc_millis': windowStartUtcMillis,
      if (windowEndUtcMillis != null)
        'window_end_utc_millis': windowEndUtcMillis,
      if (source != null) 'source': source,
      if (storyCount != null) 'story_count': storyCount,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EditionsCompanion copyWith({
    Value<String>? id,
    Value<int>? generatedAtUtcMillis,
    Value<int>? windowStartUtcMillis,
    Value<int>? windowEndUtcMillis,
    Value<String>? source,
    Value<int>? storyCount,
    Value<String>? payloadJson,
    Value<int>? rowid,
  }) {
    return EditionsCompanion(
      id: id ?? this.id,
      generatedAtUtcMillis: generatedAtUtcMillis ?? this.generatedAtUtcMillis,
      windowStartUtcMillis: windowStartUtcMillis ?? this.windowStartUtcMillis,
      windowEndUtcMillis: windowEndUtcMillis ?? this.windowEndUtcMillis,
      source: source ?? this.source,
      storyCount: storyCount ?? this.storyCount,
      payloadJson: payloadJson ?? this.payloadJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (generatedAtUtcMillis.present) {
      map['generated_at_utc_millis'] = Variable<int>(
        generatedAtUtcMillis.value,
      );
    }
    if (windowStartUtcMillis.present) {
      map['window_start_utc_millis'] = Variable<int>(
        windowStartUtcMillis.value,
      );
    }
    if (windowEndUtcMillis.present) {
      map['window_end_utc_millis'] = Variable<int>(windowEndUtcMillis.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (storyCount.present) {
      map['story_count'] = Variable<int>(storyCount.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EditionsCompanion(')
          ..write('id: $id, ')
          ..write('generatedAtUtcMillis: $generatedAtUtcMillis, ')
          ..write('windowStartUtcMillis: $windowStartUtcMillis, ')
          ..write('windowEndUtcMillis: $windowEndUtcMillis, ')
          ..write('source: $source, ')
          ..write('storyCount: $storyCount, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $EditionsTable editions = $EditionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [editions];
}

typedef $$EditionsTableCreateCompanionBuilder =
    EditionsCompanion Function({
      required String id,
      required int generatedAtUtcMillis,
      required int windowStartUtcMillis,
      required int windowEndUtcMillis,
      required String source,
      required int storyCount,
      required String payloadJson,
      Value<int> rowid,
    });
typedef $$EditionsTableUpdateCompanionBuilder =
    EditionsCompanion Function({
      Value<String> id,
      Value<int> generatedAtUtcMillis,
      Value<int> windowStartUtcMillis,
      Value<int> windowEndUtcMillis,
      Value<String> source,
      Value<int> storyCount,
      Value<String> payloadJson,
      Value<int> rowid,
    });

class $$EditionsTableFilterComposer
    extends Composer<_$AppDatabase, $EditionsTable> {
  $$EditionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get generatedAtUtcMillis => $composableBuilder(
    column: $table.generatedAtUtcMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowStartUtcMillis => $composableBuilder(
    column: $table.windowStartUtcMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowEndUtcMillis => $composableBuilder(
    column: $table.windowEndUtcMillis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get storyCount => $composableBuilder(
    column: $table.storyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EditionsTableOrderingComposer
    extends Composer<_$AppDatabase, $EditionsTable> {
  $$EditionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get generatedAtUtcMillis => $composableBuilder(
    column: $table.generatedAtUtcMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowStartUtcMillis => $composableBuilder(
    column: $table.windowStartUtcMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowEndUtcMillis => $composableBuilder(
    column: $table.windowEndUtcMillis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get storyCount => $composableBuilder(
    column: $table.storyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EditionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $EditionsTable> {
  $$EditionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get generatedAtUtcMillis => $composableBuilder(
    column: $table.generatedAtUtcMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get windowStartUtcMillis => $composableBuilder(
    column: $table.windowStartUtcMillis,
    builder: (column) => column,
  );

  GeneratedColumn<int> get windowEndUtcMillis => $composableBuilder(
    column: $table.windowEndUtcMillis,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<int> get storyCount => $composableBuilder(
    column: $table.storyCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );
}

class $$EditionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EditionsTable,
          Edition,
          $$EditionsTableFilterComposer,
          $$EditionsTableOrderingComposer,
          $$EditionsTableAnnotationComposer,
          $$EditionsTableCreateCompanionBuilder,
          $$EditionsTableUpdateCompanionBuilder,
          (Edition, BaseReferences<_$AppDatabase, $EditionsTable, Edition>),
          Edition,
          PrefetchHooks Function()
        > {
  $$EditionsTableTableManager(_$AppDatabase db, $EditionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EditionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EditionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EditionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> generatedAtUtcMillis = const Value.absent(),
                Value<int> windowStartUtcMillis = const Value.absent(),
                Value<int> windowEndUtcMillis = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> storyCount = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EditionsCompanion(
                id: id,
                generatedAtUtcMillis: generatedAtUtcMillis,
                windowStartUtcMillis: windowStartUtcMillis,
                windowEndUtcMillis: windowEndUtcMillis,
                source: source,
                storyCount: storyCount,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int generatedAtUtcMillis,
                required int windowStartUtcMillis,
                required int windowEndUtcMillis,
                required String source,
                required int storyCount,
                required String payloadJson,
                Value<int> rowid = const Value.absent(),
              }) => EditionsCompanion.insert(
                id: id,
                generatedAtUtcMillis: generatedAtUtcMillis,
                windowStartUtcMillis: windowStartUtcMillis,
                windowEndUtcMillis: windowEndUtcMillis,
                source: source,
                storyCount: storyCount,
                payloadJson: payloadJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EditionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EditionsTable,
      Edition,
      $$EditionsTableFilterComposer,
      $$EditionsTableOrderingComposer,
      $$EditionsTableAnnotationComposer,
      $$EditionsTableCreateCompanionBuilder,
      $$EditionsTableUpdateCompanionBuilder,
      (Edition, BaseReferences<_$AppDatabase, $EditionsTable, Edition>),
      Edition,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$EditionsTableTableManager get editions =>
      $$EditionsTableTableManager(_db, _db.editions);
}
