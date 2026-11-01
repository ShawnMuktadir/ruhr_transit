import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/database/app_database.dart';
import 'package:ruhr_transit/features/favourite_journeys/data/favourite_journeys_repository_impl.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';

import '../../../helpers/fake_stop_repository.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late FavouriteJourneysRepositoryImpl repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = FavouriteJourneysRepositoryImpl(db);
  });
  tearDown(() => db.close());

  final there = FavouriteJourney(
    from: bochumHbf,
    to: dortmundHbf,
    savedAt: DateTime.utc(2026, 11, 1, 7),
  );
  final back = FavouriteJourney(
    from: dortmundHbf,
    to: bochumHbf,
    savedAt: DateTime.utc(2026, 11, 1, 8),
    label: 'Home',
  );

  test('nothing saved yet is an empty list', () async {
    expect(await repository.watchAll().first, isEmpty);
  });

  test('saves journeys with their stops, oldest first', () async {
    await repository.save(back);
    await repository.save(there);

    final saved = await repository.watchAll().first;
    expect(saved.map((j) => (j.from.id, j.to.id)), [
      (bochumHbf.id, dortmundHbf.id),
      (dortmundHbf.id, bochumHbf.id),
    ]);
    expect(saved.first.from.fullName, bochumHbf.fullName);
    expect(saved.first.from.modes, bochumHbf.modes);
    expect(saved.last.label, 'Home');
    expect(saved.last.savedAt.toUtc(), back.savedAt);
  });

  test('saving the same journey again replaces it', () async {
    await repository.save(there);
    await repository.save(there.withLabel('Work'));

    final saved = await repository.watchAll().first;
    expect(saved.single.label, 'Work');
  });

  test('removes only the given direction', () async {
    await repository.save(there);
    await repository.save(back);

    await repository.remove(bochumHbf, dortmundHbf);

    final saved = await repository.watchAll().first;
    expect(saved.single.from, dortmundHbf);
  });

  test('watchers see every change', () async {
    final updates = repository.watchAll().map((list) => list.length);
    final expectation = expectLater(updates, emitsInOrder([0, 1, 2, 1]));

    await pumpEventQueue();
    await repository.save(there);
    await pumpEventQueue();
    await repository.save(back);
    await pumpEventQueue();
    await repository.remove(bochumHbf, dortmundHbf);
    await expectation;
  });
}
