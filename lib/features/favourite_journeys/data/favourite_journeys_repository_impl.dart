import 'package:drift/drift.dart';
import 'package:ruhr_transit/core/database/app_database.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journeys_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

class FavouriteJourneysRepositoryImpl implements FavouriteJourneysRepository {
  const FavouriteJourneysRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<FavouriteJourney>> watchAll() {
    final query = _db.select(_db.favouriteJourneys)
      ..orderBy([
        (row) => OrderingTerm.asc(row.savedAt),
        // Saved within the same second (drift stores seconds): stable order.
        (row) => OrderingTerm.asc(row.fromId),
        (row) => OrderingTerm.asc(row.toId),
      ]);
    return query.watch().map(
      (rows) => [
        for (final row in rows)
          FavouriteJourney(
            from: row.fromStop,
            to: row.toStop,
            label: row.label,
            savedAt: row.savedAt,
          ),
      ],
    );
  }

  @override
  Future<void> save(FavouriteJourney journey) => _db
      .into(_db.favouriteJourneys)
      .insertOnConflictUpdate(
        FavouriteJourneysCompanion.insert(
          fromId: journey.from.id,
          toId: journey.to.id,
          fromStop: journey.from,
          toStop: journey.to,
          label: Value(journey.label),
          savedAt: journey.savedAt,
        ),
      );

  @override
  Future<void> remove(Stop from, Stop to) => (_db.delete(
    _db.favouriteJourneys,
  )..where((row) => row.fromId.equals(from.id) & row.toId.equals(to.id))).go();
}
