import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/recent_stops/data/recent_stops_repository_impl.dart';
import 'package:ruhr_transit/features/recent_stops/presentation/recent_stops_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fake_recent_stops_repository.dart';
import '../../helpers/fake_stop_repository.dart';

Stop stopNumber(int n) => Stop(
  id: 'de:05911:$n',
  name: 'Stop $n',
  fullName: 'Bochum, Stop $n',
  latitude: 51.4,
  longitude: 7.2,
);

void main() {
  group('RecentStopsRepositoryImpl', () {
    late SharedPreferencesAsync preferences;
    late RecentStopsRepositoryImpl repository;

    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      preferences = SharedPreferencesAsync();
      repository = RecentStopsRepositoryImpl(preferences);
    });

    test('nothing saved yet is an empty history', () async {
      expect(await repository.load(), isEmpty);
    });

    test('saves and loads stops in order, with their details', () async {
      await repository.save([bochumHbf, dortmundHbf]);

      final loaded = await RecentStopsRepositoryImpl(preferences).load();
      expect(loaded, [bochumHbf, dortmundHbf]);
      expect(loaded.first.fullName, 'Bochum, Hbf');
      expect(loaded.first.modes, contains(TransportMode.train));
    });

    test('an empty history removes the entry', () async {
      await repository.save([bochumHbf]);
      await repository.save(const []);

      expect(
        await preferences.getString(RecentStopsRepositoryImpl.storageKey),
        isNull,
      );
    });

    test('broken data costs only what is broken', () async {
      await preferences.setString(
        RecentStopsRepositoryImpl.storageKey,
        '[{"id":"broken"},'
        '{"id":"de:05911:5194","name":"Hbf","fullName":"Bochum, Hbf",'
        '"latitude":51.4,"longitude":7.2}]',
      );
      expect(await repository.load(), [bochumHbf]);

      await preferences.setString(
        RecentStopsRepositoryImpl.storageKey,
        'not json',
      );
      expect(await repository.load(), isEmpty);
    });
  });

  group('RecentStopsCubit', () {
    late FakeRecentStopsRepository repository;

    setUp(() => repository = FakeRecentStopsRepository());

    test('a pick goes first and appears only once', () async {
      final cubit = RecentStopsCubit(
        repository,
        initial: [bochumHbf, dortmundHbf],
      )..add(dortmundHbf);
      await pumpEventQueue();

      expect(cubit.state, [dortmundHbf, bochumHbf]);
      expect(repository.saved, [dortmundHbf, bochumHbf]);
    });

    test('keeps the latest ten', () async {
      final cubit = RecentStopsCubit(repository);
      for (var i = 1; i <= 12; i++) {
        cubit.add(stopNumber(i));
      }
      await pumpEventQueue();

      expect(cubit.state, hasLength(RecentStopsCubit.limit));
      expect(cubit.state.first, stopNumber(12));
      expect(cubit.state.last, stopNumber(3));
      expect(repository.saved, hasLength(10));
    });

    test('starts with at most ten stored stops', () {
      final cubit = RecentStopsCubit(
        repository,
        initial: [for (var i = 1; i <= 12; i++) stopNumber(i)],
      );

      expect(cubit.state, hasLength(10));
    });

    test('remove and restore put a stop back in its place', () async {
      final cubit = RecentStopsCubit(
        repository,
        initial: [bochumHbf, dortmundHbf],
      );

      final index = cubit.remove(bochumHbf);
      expect(cubit.state, [dortmundHbf]);
      cubit.restore(bochumHbf, index);
      await pumpEventQueue();

      expect(cubit.state, [bochumHbf, dortmundHbf]);
      expect(repository.saved, [bochumHbf, dortmundHbf]);
    });

    test('clear empties the history and can be undone', () async {
      final cubit = RecentStopsCubit(
        repository,
        initial: [bochumHbf, dortmundHbf],
      );

      final previous = cubit.clear();
      await pumpEventQueue();
      expect(cubit.state, isEmpty);
      expect(repository.saved, isEmpty);

      cubit.restoreAll(previous);
      await pumpEventQueue();
      expect(repository.saved, [bochumHbf, dortmundHbf]);
    });
  });
}
