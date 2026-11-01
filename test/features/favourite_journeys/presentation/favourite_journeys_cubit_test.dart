import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_stop_repository.dart';

void main() {
  final now = DateTime.utc(2026, 11, 1, 9);
  late FakeFavouriteJourneysRepository repository;

  FavouriteJourneysCubit cubit() =>
      FavouriteJourneysCubit(repository, now: () => now);

  List<FavouriteJourney> journeys(FavouriteJourneysCubit cubit) =>
      (cubit.state as FavouriteJourneysLoaded).journeys;

  setUp(() => repository = FakeFavouriteJourneysRepository());

  test('loads the saved journeys', () async {
    repository.saved = [
      FavouriteJourney(from: bochumHbf, to: dortmundHbf, savedAt: now),
    ];
    final journeysCubit = cubit();
    expect(journeysCubit.state, isA<FavouriteJourneysLoading>());

    await pumpEventQueue();

    expect(journeys(journeysCubit).single.to, dortmundHbf);
    await journeysCubit.close();
  });

  test('a read error shows the error state, retry recovers', () async {
    repository.readError = Exception('disk');
    final journeysCubit = cubit();
    await pumpEventQueue();
    expect(journeysCubit.state, isA<FavouriteJourneysFailed>());

    repository.readError = null;
    journeysCubit.retry();
    await pumpEventQueue();
    expect(journeys(journeysCubit), isEmpty);
    await journeysCubit.close();
  });

  test('toggle saves, then removes, one direction', () async {
    final journeysCubit = cubit();
    await pumpEventQueue();

    await journeysCubit.toggle(bochumHbf, dortmundHbf);
    await pumpEventQueue();
    expect(journeysCubit.find(bochumHbf, dortmundHbf)?.savedAt, now);
    expect(journeysCubit.find(dortmundHbf, bochumHbf), isNull);

    await journeysCubit.toggle(bochumHbf, dortmundHbf);
    await pumpEventQueue();
    expect(journeysCubit.find(bochumHbf, dortmundHbf), isNull);
    await journeysCubit.close();
  });

  test('restore puts a removed journey back in its place', () async {
    final first = FavouriteJourney(
      from: bochumHbf,
      to: dortmundHbf,
      savedAt: DateTime.utc(2026, 3, 5),
      label: 'Work',
    );
    final second = FavouriteJourney(
      from: dortmundHbf,
      to: bochumHbf,
      savedAt: DateTime.utc(2026, 4, 5),
    );
    repository.saved = [first, second];
    final journeysCubit = cubit();
    await pumpEventQueue();

    await journeysCubit.remove(first);
    await pumpEventQueue();
    expect(journeys(journeysCubit), hasLength(1));

    await journeysCubit.restore(first);
    await pumpEventQueue();
    expect(journeys(journeysCubit).first.label, 'Work');
    expect(journeys(journeysCubit).first.from, bochumHbf);
    await journeysCubit.close();
  });

  test('setLabel trims and clears the label', () async {
    final journey = FavouriteJourney(
      from: bochumHbf,
      to: dortmundHbf,
      savedAt: now,
    );
    repository.saved = [journey];
    final journeysCubit = cubit();
    await pumpEventQueue();

    await journeysCubit.setLabel(journey, '  RE1 at 7:40 ');
    await pumpEventQueue();
    expect(journeys(journeysCubit).single.label, 'RE1 at 7:40');

    await journeysCubit.setLabel(journey, '   ');
    await pumpEventQueue();
    expect(journeys(journeysCubit).single.label, isNull);
    await journeysCubit.close();
  });
}
