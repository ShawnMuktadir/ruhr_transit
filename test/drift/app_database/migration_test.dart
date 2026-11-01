import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/database/app_database.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

/// Checks the app's tables against the schema snapshots in drift_schemas/.
///
/// After changing a table: raise AppDatabase.schemaVersion, run
/// `dart run drift_dev make-migrations`, and add a "migrates from vN" test
/// below that writes rows with the old schema and reads them after the
/// upgrade.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('every snapshot upgrades to the current schema', () async {
    for (final version in GeneratedHelper.versions) {
      final schema = await verifier.schemaAt(version);
      final db = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, db.schemaVersion);
      await db.close();
    }
  });

  test('a fresh install creates the schema the code expects', () async {
    final db = AppDatabase(NativeDatabase.memory());
    await db.validateDatabaseSchema();
    await db.close();
  });

  test('rows written with schema v1 are read by the current code', () async {
    final schema = await verifier.schemaAt(1);
    final old = v1.DatabaseAtV1(schema.newConnection());
    await old
        .into(old.favouriteJourneys)
        .insert(
          v1.FavouriteJourneysCompanion.insert(
            fromId: 'de:05911:5194',
            toId: 'de:05913:131',
            fromStop: _bochumJson,
            toStop: _dortmundJson,
            label: const Value('Work'),
            // drift stores DateTime as unix seconds.
            savedAt:
                DateTime.utc(2026, 11, 1, 7).millisecondsSinceEpoch ~/ 1000,
          ),
        );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    final rows = await db.select(db.favouriteJourneys).get();
    expect(rows.single.fromStop.fullName, 'Bochum, Hbf');
    expect(rows.single.toStop.id, 'de:05913:131');
    expect(rows.single.label, 'Work');
    expect(rows.single.savedAt.toUtc(), DateTime.utc(2026, 11, 1, 7));
    await db.close();
  });
}

const _bochumJson =
    '{"id":"de:05911:5194","name":"Hbf","fullName":"Bochum, Hbf",'
    '"locality":"Bochum","latitude":51.4,"longitude":7.2,"modes":["train"]}';

const _dortmundJson =
    '{"id":"de:05913:131","name":"Hbf","fullName":"Dortmund, Hbf",'
    '"locality":"Dortmund","latitude":51.5,"longitude":7.4,"modes":[]}';
