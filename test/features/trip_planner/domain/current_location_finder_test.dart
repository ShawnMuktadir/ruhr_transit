import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/trip_planner/domain/current_location_finder.dart';

import '../../../helpers/fake_nearby_stops.dart';
import '../../../helpers/fake_stop_repository.dart';

void main() {
  late FakeLocationSource location;
  late FakeStopRepository stops;
  late CurrentLocationFinder finder;

  setUp(() {
    location = FakeLocationSource();
    stops = FakeStopRepository();
    finder = CurrentLocationFinder(location, stops);
  });

  test('finds the address at the position', () async {
    final result = await finder.find();

    expect(result, isA<HereFound>().having((r) => r.stop, 'stop', kortumstr10));
    expect(stops.locationPoints, [
      (bochumHbfLocation.latitude, bochumHbfLocation.longitude),
    ]);
  });

  test('reports why there is no position, without asking VRR', () async {
    final cases = {
      const LocationOff(): isA<HereLocationOff>(),
      const LocationPermissionDenied(permanently: false): isA<HereDenied>()
          .having((r) => r.permanently, 'permanently', isFalse),
      const LocationPermissionDenied(permanently: true): isA<HereDenied>()
          .having((r) => r.permanently, 'permanently', isTrue),
      const LocationTimeout(): isA<HereNoPosition>(),
    };
    for (final MapEntry(key: answer, value: matcher) in cases.entries) {
      location.result = answer;
      expect(await finder.find(), matcher);
    }
    expect(stops.locationPoints, isEmpty);
  });

  test('no address there, or the lookup failed', () async {
    stops.locationReply = const Ok(null);
    expect(await finder.find(), isA<HereNothingThere>());

    stops.locationReply = const Err(NetworkFailure());
    expect(
      await finder.find(),
      isA<HereFailed>().having(
        (r) => r.failure,
        'failure',
        isA<NetworkFailure>(),
      ),
    );
  });

  test('opens the settings through the location source', () async {
    await finder.openAppSettings();
    await finder.openLocationSettings();

    expect(location.appSettingsOpened, 1);
    expect(location.locationSettingsOpened, 1);
  });
}
