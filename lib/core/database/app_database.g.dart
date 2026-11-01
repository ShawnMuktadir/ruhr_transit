// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $FavouriteJourneysTable extends FavouriteJourneys
    with TableInfo<$FavouriteJourneysTable, FavouriteJourneyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavouriteJourneysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fromIdMeta = const VerificationMeta('fromId');
  @override
  late final GeneratedColumn<String> fromId = GeneratedColumn<String>(
    'from_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _toIdMeta = const VerificationMeta('toId');
  @override
  late final GeneratedColumn<String> toId = GeneratedColumn<String>(
    'to_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<Stop, String> fromStop =
      GeneratedColumn<String>(
        'from_stop',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Stop>($FavouriteJourneysTable.$converterfromStop);
  @override
  late final GeneratedColumnWithTypeConverter<Stop, String> toStop =
      GeneratedColumn<String>(
        'to_stop',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<Stop>($FavouriteJourneysTable.$convertertoStop);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<DateTime> savedAt = GeneratedColumn<DateTime>(
    'saved_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fromId,
    toId,
    fromStop,
    toStop,
    label,
    savedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favourite_journeys';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavouriteJourneyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('from_id')) {
      context.handle(
        _fromIdMeta,
        fromId.isAcceptableOrUnknown(data['from_id']!, _fromIdMeta),
      );
    } else if (isInserting) {
      context.missing(_fromIdMeta);
    }
    if (data.containsKey('to_id')) {
      context.handle(
        _toIdMeta,
        toId.isAcceptableOrUnknown(data['to_id']!, _toIdMeta),
      );
    } else if (isInserting) {
      context.missing(_toIdMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_savedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fromId, toId};
  @override
  FavouriteJourneyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavouriteJourneyRow(
      fromId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}from_id'],
      )!,
      toId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}to_id'],
      )!,
      fromStop: $FavouriteJourneysTable.$converterfromStop.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}from_stop'],
        )!,
      ),
      toStop: $FavouriteJourneysTable.$convertertoStop.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}to_stop'],
        )!,
      ),
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      ),
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}saved_at'],
      )!,
    );
  }

  @override
  $FavouriteJourneysTable createAlias(String alias) {
    return $FavouriteJourneysTable(attachedDatabase, alias);
  }

  static TypeConverter<Stop, String> $converterfromStop = const StopConverter();
  static TypeConverter<Stop, String> $convertertoStop = const StopConverter();
}

class FavouriteJourneyRow extends DataClass
    implements Insertable<FavouriteJourneyRow> {
  final String fromId;
  final String toId;
  final Stop fromStop;
  final Stop toStop;
  final String? label;
  final DateTime savedAt;
  const FavouriteJourneyRow({
    required this.fromId,
    required this.toId,
    required this.fromStop,
    required this.toStop,
    this.label,
    required this.savedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['from_id'] = Variable<String>(fromId);
    map['to_id'] = Variable<String>(toId);
    {
      map['from_stop'] = Variable<String>(
        $FavouriteJourneysTable.$converterfromStop.toSql(fromStop),
      );
    }
    {
      map['to_stop'] = Variable<String>(
        $FavouriteJourneysTable.$convertertoStop.toSql(toStop),
      );
    }
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    map['saved_at'] = Variable<DateTime>(savedAt);
    return map;
  }

  FavouriteJourneysCompanion toCompanion(bool nullToAbsent) {
    return FavouriteJourneysCompanion(
      fromId: Value(fromId),
      toId: Value(toId),
      fromStop: Value(fromStop),
      toStop: Value(toStop),
      label: label == null && nullToAbsent
          ? const Value.absent()
          : Value(label),
      savedAt: Value(savedAt),
    );
  }

  factory FavouriteJourneyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavouriteJourneyRow(
      fromId: serializer.fromJson<String>(json['fromId']),
      toId: serializer.fromJson<String>(json['toId']),
      fromStop: serializer.fromJson<Stop>(json['fromStop']),
      toStop: serializer.fromJson<Stop>(json['toStop']),
      label: serializer.fromJson<String?>(json['label']),
      savedAt: serializer.fromJson<DateTime>(json['savedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fromId': serializer.toJson<String>(fromId),
      'toId': serializer.toJson<String>(toId),
      'fromStop': serializer.toJson<Stop>(fromStop),
      'toStop': serializer.toJson<Stop>(toStop),
      'label': serializer.toJson<String?>(label),
      'savedAt': serializer.toJson<DateTime>(savedAt),
    };
  }

  FavouriteJourneyRow copyWith({
    String? fromId,
    String? toId,
    Stop? fromStop,
    Stop? toStop,
    Value<String?> label = const Value.absent(),
    DateTime? savedAt,
  }) => FavouriteJourneyRow(
    fromId: fromId ?? this.fromId,
    toId: toId ?? this.toId,
    fromStop: fromStop ?? this.fromStop,
    toStop: toStop ?? this.toStop,
    label: label.present ? label.value : this.label,
    savedAt: savedAt ?? this.savedAt,
  );
  FavouriteJourneyRow copyWithCompanion(FavouriteJourneysCompanion data) {
    return FavouriteJourneyRow(
      fromId: data.fromId.present ? data.fromId.value : this.fromId,
      toId: data.toId.present ? data.toId.value : this.toId,
      fromStop: data.fromStop.present ? data.fromStop.value : this.fromStop,
      toStop: data.toStop.present ? data.toStop.value : this.toStop,
      label: data.label.present ? data.label.value : this.label,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavouriteJourneyRow(')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('fromStop: $fromStop, ')
          ..write('toStop: $toStop, ')
          ..write('label: $label, ')
          ..write('savedAt: $savedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(fromId, toId, fromStop, toStop, label, savedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavouriteJourneyRow &&
          other.fromId == this.fromId &&
          other.toId == this.toId &&
          other.fromStop == this.fromStop &&
          other.toStop == this.toStop &&
          other.label == this.label &&
          other.savedAt == this.savedAt);
}

class FavouriteJourneysCompanion extends UpdateCompanion<FavouriteJourneyRow> {
  final Value<String> fromId;
  final Value<String> toId;
  final Value<Stop> fromStop;
  final Value<Stop> toStop;
  final Value<String?> label;
  final Value<DateTime> savedAt;
  final Value<int> rowid;
  const FavouriteJourneysCompanion({
    this.fromId = const Value.absent(),
    this.toId = const Value.absent(),
    this.fromStop = const Value.absent(),
    this.toStop = const Value.absent(),
    this.label = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavouriteJourneysCompanion.insert({
    required String fromId,
    required String toId,
    required Stop fromStop,
    required Stop toStop,
    this.label = const Value.absent(),
    required DateTime savedAt,
    this.rowid = const Value.absent(),
  }) : fromId = Value(fromId),
       toId = Value(toId),
       fromStop = Value(fromStop),
       toStop = Value(toStop),
       savedAt = Value(savedAt);
  static Insertable<FavouriteJourneyRow> custom({
    Expression<String>? fromId,
    Expression<String>? toId,
    Expression<String>? fromStop,
    Expression<String>? toStop,
    Expression<String>? label,
    Expression<DateTime>? savedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fromId != null) 'from_id': fromId,
      if (toId != null) 'to_id': toId,
      if (fromStop != null) 'from_stop': fromStop,
      if (toStop != null) 'to_stop': toStop,
      if (label != null) 'label': label,
      if (savedAt != null) 'saved_at': savedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavouriteJourneysCompanion copyWith({
    Value<String>? fromId,
    Value<String>? toId,
    Value<Stop>? fromStop,
    Value<Stop>? toStop,
    Value<String?>? label,
    Value<DateTime>? savedAt,
    Value<int>? rowid,
  }) {
    return FavouriteJourneysCompanion(
      fromId: fromId ?? this.fromId,
      toId: toId ?? this.toId,
      fromStop: fromStop ?? this.fromStop,
      toStop: toStop ?? this.toStop,
      label: label ?? this.label,
      savedAt: savedAt ?? this.savedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fromId.present) {
      map['from_id'] = Variable<String>(fromId.value);
    }
    if (toId.present) {
      map['to_id'] = Variable<String>(toId.value);
    }
    if (fromStop.present) {
      map['from_stop'] = Variable<String>(
        $FavouriteJourneysTable.$converterfromStop.toSql(fromStop.value),
      );
    }
    if (toStop.present) {
      map['to_stop'] = Variable<String>(
        $FavouriteJourneysTable.$convertertoStop.toSql(toStop.value),
      );
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<DateTime>(savedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavouriteJourneysCompanion(')
          ..write('fromId: $fromId, ')
          ..write('toId: $toId, ')
          ..write('fromStop: $fromStop, ')
          ..write('toStop: $toStop, ')
          ..write('label: $label, ')
          ..write('savedAt: $savedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FavouriteJourneysTable favouriteJourneys =
      $FavouriteJourneysTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [favouriteJourneys];
}

typedef $$FavouriteJourneysTableCreateCompanionBuilder =
    FavouriteJourneysCompanion Function({
      required String fromId,
      required String toId,
      required Stop fromStop,
      required Stop toStop,
      Value<String?> label,
      required DateTime savedAt,
      Value<int> rowid,
    });
typedef $$FavouriteJourneysTableUpdateCompanionBuilder =
    FavouriteJourneysCompanion Function({
      Value<String> fromId,
      Value<String> toId,
      Value<Stop> fromStop,
      Value<Stop> toStop,
      Value<String?> label,
      Value<DateTime> savedAt,
      Value<int> rowid,
    });

class $$FavouriteJourneysTableFilterComposer
    extends Composer<_$AppDatabase, $FavouriteJourneysTable> {
  $$FavouriteJourneysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fromId => $composableBuilder(
    column: $table.fromId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get toId => $composableBuilder(
    column: $table.toId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<Stop, Stop, String> get fromStop =>
      $composableBuilder(
        column: $table.fromStop,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<Stop, Stop, String> get toStop =>
      $composableBuilder(
        column: $table.toStop,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FavouriteJourneysTableOrderingComposer
    extends Composer<_$AppDatabase, $FavouriteJourneysTable> {
  $$FavouriteJourneysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fromId => $composableBuilder(
    column: $table.fromId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toId => $composableBuilder(
    column: $table.toId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fromStop => $composableBuilder(
    column: $table.fromStop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get toStop => $composableBuilder(
    column: $table.toStop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavouriteJourneysTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavouriteJourneysTable> {
  $$FavouriteJourneysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fromId =>
      $composableBuilder(column: $table.fromId, builder: (column) => column);

  GeneratedColumn<String> get toId =>
      $composableBuilder(column: $table.toId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Stop, String> get fromStop =>
      $composableBuilder(column: $table.fromStop, builder: (column) => column);

  GeneratedColumnWithTypeConverter<Stop, String> get toStop =>
      $composableBuilder(column: $table.toStop, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<DateTime> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);
}

class $$FavouriteJourneysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavouriteJourneysTable,
          FavouriteJourneyRow,
          $$FavouriteJourneysTableFilterComposer,
          $$FavouriteJourneysTableOrderingComposer,
          $$FavouriteJourneysTableAnnotationComposer,
          $$FavouriteJourneysTableCreateCompanionBuilder,
          $$FavouriteJourneysTableUpdateCompanionBuilder,
          (
            FavouriteJourneyRow,
            BaseReferences<
              _$AppDatabase,
              $FavouriteJourneysTable,
              FavouriteJourneyRow
            >,
          ),
          FavouriteJourneyRow,
          PrefetchHooks Function()
        > {
  $$FavouriteJourneysTableTableManager(
    _$AppDatabase db,
    $FavouriteJourneysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavouriteJourneysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavouriteJourneysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavouriteJourneysTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> fromId = const Value.absent(),
                Value<String> toId = const Value.absent(),
                Value<Stop> fromStop = const Value.absent(),
                Value<Stop> toStop = const Value.absent(),
                Value<String?> label = const Value.absent(),
                Value<DateTime> savedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavouriteJourneysCompanion(
                fromId: fromId,
                toId: toId,
                fromStop: fromStop,
                toStop: toStop,
                label: label,
                savedAt: savedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fromId,
                required String toId,
                required Stop fromStop,
                required Stop toStop,
                Value<String?> label = const Value.absent(),
                required DateTime savedAt,
                Value<int> rowid = const Value.absent(),
              }) => FavouriteJourneysCompanion.insert(
                fromId: fromId,
                toId: toId,
                fromStop: fromStop,
                toStop: toStop,
                label: label,
                savedAt: savedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FavouriteJourneysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavouriteJourneysTable,
      FavouriteJourneyRow,
      $$FavouriteJourneysTableFilterComposer,
      $$FavouriteJourneysTableOrderingComposer,
      $$FavouriteJourneysTableAnnotationComposer,
      $$FavouriteJourneysTableCreateCompanionBuilder,
      $$FavouriteJourneysTableUpdateCompanionBuilder,
      (
        FavouriteJourneyRow,
        BaseReferences<
          _$AppDatabase,
          $FavouriteJourneysTable,
          FavouriteJourneyRow
        >,
      ),
      FavouriteJourneyRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FavouriteJourneysTableTableManager get favouriteJourneys =>
      $$FavouriteJourneysTableTableManager(_db, _db.favouriteJourneys);
}
