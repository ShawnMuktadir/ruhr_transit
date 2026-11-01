import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:ruhr_transit/features/favourite_journeys/data/favourite_journeys_table.dart';
// The generated code uses Stop for the table's converted columns.
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

part 'app_database.g.dart';

/// The app's SQLite database (drift). Small settings stay in
/// shared_preferences; this holds data with a structure worth querying.
///
/// Changing a table: raise [schemaVersion], run
/// `dart run drift_dev make-migrations`, add the step to [migration] and
/// fill in the generated migration test.
@DriftDatabase(tables: [FavouriteJourneys])
class AppDatabase extends _$AppDatabase {
  /// [executor] is for tests (an in-memory database); the app uses a file
  /// in its private storage.
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'ruhr_transit'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Version 1 is the first schema; there is nothing to upgrade from yet.
  );
}
