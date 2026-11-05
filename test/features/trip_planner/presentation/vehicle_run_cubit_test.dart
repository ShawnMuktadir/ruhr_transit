import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/vehicle_run_cubit.dart';

import '../../../helpers/fake_vehicle_run_repository.dart';

void main() {
  final key = RunKey(
    lineId: 'line',
    tripCode: '1',
    stopId: 'de:05911:5600:8:8',
    plannedDeparture: DateTime.utc(2026, 11, 2, 7, 21),
  );

  test('loads the run and places the vehicle at the time of loading', () {
    fakeAsync((async) {
      final repository = FakeVehicleRunRepository();
      var now = DateTime.utc(2026, 11, 2, 7, 20);
      final cubit = VehicleRunCubit(repository, key, now: () => now)..start();
      async.flushMicrotasks();

      final loaded = cubit.state as VehicleRunLoaded;
      expect(loaded.run, u35Run);
      expect(
        loaded.position,
        isA<RunBetween>().having((p) => p.from, 'from', 1),
      );
      expect(repository.keys, [key]);

      // 30 seconds later it asks again and moves on.
      now = DateTime.utc(2026, 11, 2, 7, 21);
      async.elapse(const Duration(seconds: 30));
      expect(repository.keys, hasLength(2));
      expect(
        (cubit.state as VehicleRunLoaded).position,
        isA<RunAtStop>().having((p) => p.index, 'index', 2),
      );

      cubit.close();
      async.elapse(const Duration(minutes: 5));
      // Closing stops the refresh.
      expect(repository.keys, hasLength(2));
    });
  });

  test('a first failure shows as failed', () async {
    final repository = FakeVehicleRunRepository(const Err(NetworkFailure()));
    final cubit = VehicleRunCubit(repository, key);

    await cubit.load();

    expect(cubit.state, isA<VehicleRunFailed>());
    await cubit.close();
  });

  test(
    'after a server error the run stays and the position moves on',
    () async {
      final repository = FakeVehicleRunRepository();
      var now = DateTime.utc(2026, 11, 2, 7, 20);
      final cubit = VehicleRunCubit(repository, key, now: () => now);
      await cubit.load();

      repository.reply = const Err(ServerFailure(code: 500));
      now = DateTime.utc(2026, 11, 2, 7, 40);
      await cubit.load();

      final state = cubit.state as VehicleRunLoaded;
      expect(state.run, u35Run);
      expect(state.isPaused, isFalse);
      expect(state.position, isA<RunEnded>());
      await cubit.close();
    },
  );

  test('without a connection the position pauses, then carries on', () async {
    for (final failure in const [NetworkFailure(), TimeoutFailure()]) {
      final repository = FakeVehicleRunRepository();
      var now = DateTime.utc(2026, 11, 2, 7, 20);
      final cubit = VehicleRunCubit(repository, key, now: () => now);
      await cubit.load();
      final before = (cubit.state as VehicleRunLoaded).position;

      repository.reply = Err(failure);
      now = DateTime.utc(2026, 11, 2, 7, 40);
      await cubit.load();

      var state = cubit.state as VehicleRunLoaded;
      expect(state.isPaused, isTrue);
      expect(state.now, DateTime.utc(2026, 11, 2, 7, 20));
      expect(state.position.runtimeType, before.runtimeType);

      // Still offline: the time of the last answer does not creep on.
      now = DateTime.utc(2026, 11, 2, 7, 50);
      await cubit.load();
      expect((cubit.state as VehicleRunLoaded).now, state.now);

      repository.reply = Ok(u35Run);
      await cubit.load();
      state = cubit.state as VehicleRunLoaded;
      expect(state.isPaused, isFalse);
      expect(state.now, now);
      await cubit.close();
    }
  });
}
