import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

import '../../../helpers/fake_favourites_repository.dart';
import '../../../helpers/fake_stop_repository.dart';

const _third = Stop(
  id: 'de:05911:5691',
  name: 'Rathaus (U)',
  fullName: 'Bochum, Rathaus (U)',
  latitude: 51.48,
  longitude: 7.21,
);

void main() {
  late FakeFavouritesRepository repository;
  late FavouritesCubit cubit;

  setUp(() {
    repository = FakeFavouritesRepository();
    cubit = FavouritesCubit(repository);
  });

  tearDown(() => cubit.close());

  test('starts with the stops loaded before the app started', () {
    final loaded = FavouritesCubit(
      repository,
      initial: [bochumHbf, dortmundHbf],
    );
    addTearDown(loaded.close);

    expect(loaded.state, [bochumHbf, dortmundHbf]);
    expect(cubit.state, isEmpty);
  });

  test('a change keeps the stops that were already saved', () async {
    repository.saved = [dortmundHbf];
    final loaded = FavouritesCubit(repository, initial: [dortmundHbf])
      ..toggle(bochumHbf);
    addTearDown(loaded.close);
    await pumpEventQueue();

    expect(repository.saved, [dortmundHbf, bochumHbf]);
  });

  test('toggle adds at the end, removes, and saves each change', () async {
    cubit
      ..toggle(bochumHbf)
      ..toggle(dortmundHbf);
    expect(cubit.state, [bochumHbf, dortmundHbf]);
    expect(cubit.isFavourite(dortmundHbf), isTrue);

    cubit.toggle(bochumHbf);
    await pumpEventQueue();

    expect(cubit.state, [dortmundHbf]);
    expect(cubit.isFavourite(bochumHbf), isFalse);
    expect(repository.saved, [dortmundHbf]);
    expect(repository.saveCount, 3);
  });

  test('restore puts a removed stop back where it was', () async {
    cubit
      ..toggle(bochumHbf)
      ..toggle(_third)
      ..toggle(dortmundHbf);

    final index = cubit.remove(_third);
    expect(index, 1);
    expect(cubit.state, [bochumHbf, dortmundHbf]);

    cubit.restore(_third, index);
    await pumpEventQueue();

    expect(cubit.state, [bochumHbf, _third, dortmundHbf]);
    expect(repository.saved, [bochumHbf, _third, dortmundHbf]);
  });

  test('restore clamps the position and never duplicates', () {
    cubit
      ..toggle(bochumHbf)
      ..toggle(dortmundHbf);
    final index = cubit.remove(dortmundHbf);
    cubit.remove(bochumHbf);

    cubit.restore(dortmundHbf, index);
    cubit.restore(dortmundHbf, 0);

    expect(cubit.state, [dortmundHbf]);
  });

  test('removing a stop that is not a favourite changes nothing', () {
    expect(cubit.remove(bochumHbf), -1);
    expect(repository.saveCount, 0);
  });

  test('the state cannot be modified from outside', () {
    cubit.toggle(bochumHbf);

    expect(() => cubit.state.add(dortmundHbf), throwsUnsupportedError);
  });
}
