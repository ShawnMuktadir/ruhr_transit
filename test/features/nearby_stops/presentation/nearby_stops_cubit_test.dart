import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_state.dart';

import '../../../helpers/fake_nearby_stops.dart';

void main() {
  late FakeLocationSource location;
  late FakeNearbyStopsRepository repository;
  late NearbyStopsCubit cubit;
  late List<NearbyStopsState> states;

  setUp(() {
    location = FakeLocationSource();
    repository = FakeNearbyStopsRepository();
    cubit = NearbyStopsCubit(location, repository);
    states = [];
    cubit.stream.listen(states.add);
  });

  tearDown(() => cubit.close());

  test('does not read the location by itself', () {
    expect(cubit.state, isA<NearbyLocating>());
    expect(location.calls, 0);
  });

  test('locates, then loads the stops around that point', () async {
    await cubit.load();

    await pumpEventQueue();
    expect(states.map((s) => s.runtimeType), [
      NearbyLocating,
      NearbyLoading,
      NearbyLoaded,
    ]);
    expect(repository.points, [(51.4794, 7.2233)]);
    expect(
      cubit.state,
      isA<NearbyLoaded>()
          .having((s) => s.stops, 'stops', nearbyStops)
          .having((s) => s.isApproximate, 'isApproximate', isFalse),
    );
  });

  test('passes on that the location was approximate', () async {
    location.result = const Located(
      latitude: 51.4,
      longitude: 7.2,
      isApproximate: true,
    );

    await cubit.load();

    expect(
      cubit.state,
      isA<NearbyLoaded>().having((s) => s.isApproximate, 'isApproximate', true),
    );
  });

  test('each location problem is shown and nothing is requested', () async {
    for (final problem in const [
      LocationOff(),
      LocationPermissionDenied(permanently: false),
      LocationPermissionDenied(permanently: true),
      LocationTimeout(),
    ]) {
      location.result = problem;

      await cubit.load();

      expect(
        cubit.state,
        isA<NearbyLocationProblem>().having(
          (s) => s.problem,
          'problem',
          same(problem),
        ),
      );
    }
    expect(repository.points, isEmpty);
  });

  test('no stops nearby is loaded, not an error', () async {
    repository.reply = const Ok([]);

    await cubit.load();

    expect(
      cubit.state,
      isA<NearbyLoaded>().having((s) => s.stops, 'stops', isEmpty),
    );
  });

  test('a failed request shows the failure; retry loads again', () async {
    repository.reply = const Err(NetworkFailure());
    await cubit.load();
    expect(
      cubit.state,
      isA<NearbyFailed>().having(
        (s) => s.failure,
        'failure',
        isA<NetworkFailure>(),
      ),
    );

    repository.reply = const Ok(nearbyStops);
    await cubit.load();

    expect(location.calls, 2);
    expect(cubit.state, isA<NearbyLoaded>());
  });

  test('a second load while locating is ignored', () async {
    final pending = location.pending = Completer();

    final first = cubit.load();
    final second = cubit.load();
    pending.complete(bochumHbfLocation);
    await Future.wait([first, second]);

    // Android allows only one permission request at a time.
    expect(location.calls, 1);
    expect(repository.points, hasLength(1));
  });

  test('a location arriving after the page closed is ignored', () async {
    final pending = location.pending = Completer();
    final load = cubit.load();
    await cubit.close();

    pending.complete(bochumHbfLocation);
    await load;

    expect(repository.points, isEmpty);
  });

  test('opens the settings through the location source', () async {
    await cubit.openAppSettings();
    await cubit.openLocationSettings();

    expect(location.appSettingsOpened, 1);
    expect(location.locationSettingsOpened, 1);
  });
}
