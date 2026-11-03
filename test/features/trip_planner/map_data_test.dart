import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/features/trip_planner/data/run_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_map_page.dart';

import '../../helpers/fixtures.dart';

void main() {
  group('readGeoPoint', () {
    test('reads [latitude, longitude]', () {
      expect(
        readGeoPoint([51.479466, 7.223335]),
        const GeoPoint(51.479466, 7.223335),
      );
      expect(readGeoPoint([51, 7]), const GeoPoint(51, 7));
    });

    test("never EFA's own projection or broken values", () {
      // What the run request sends without coordOutputFormat.
      expect(readGeoPoint([5257778.0, 869215.0]), isNull);
      expect(readGeoPoint([51.4]), isNull);
      expect(readGeoPoint('51,7'), isNull);
      expect(readGeoPoint(null), isNull);
    });

    test('a path skips points it cannot read', () {
      expect(
        readGeoPath([
          [51.0, 7.0],
          [9999999.0, 1.0],
          [51.1, 7.1],
        ]),
        const [GeoPoint(51, 7), GeoPoint(51.1, 7.1)],
      );
      expect(readGeoPath(null), isEmpty);
    });
  });

  group('trips with recorded responses', () {
    final journeys = mapTripResponse(readEfaFixtureJson('trip_with_walk'));
    final [u35, walk, bus] = journeys.first.legs;

    test('legs carry their path and stops their positions', () {
      expect(u35.path, hasLength(146));
      expect(u35.path.first, const GeoPoint(51.447061, 7.258388));
      expect(u35.origin.position, const GeoPoint(51.447073, 7.258387));
      expect(walk.path, hasLength(21));
      expect(bus.destination.position, isNotNull);
      expect(
        (u35 as TransitLeg).intermediateStops.map((s) => s.position),
        everyElement(isNotNull),
      );
    });

    test('the map draws a leg by its path, else straight between stops', () {
      expect(legLine(u35), u35.path);
      final straight = WalkLeg(
        duration: const Duration(minutes: 3),
        origin: TripStop(
          name: 'A',
          plannedTime: DateTime.utc(2026, 11, 3, 8),
          position: const GeoPoint(51, 7),
        ),
        destination: TripStop(
          name: 'B',
          plannedTime: DateTime.utc(2026, 11, 3, 8, 3),
          position: const GeoPoint(51.001, 7.001),
        ),
      );
      expect(legLine(straight), const [
        GeoPoint(51, 7),
        GeoPoint(51.001, 7.001),
      ]);
      expect(hasMap(journeys.first), isTrue);
    });

    test('a run recorded in EFA projection has no positions', () {
      // stopseq_run.json predates coordOutputFormat=WGS84 on the request.
      final run = mapRunResponse(readEfaFixtureJson('stopseq_run'));
      expect(run.stops.map((s) => s.position), everyElement(isNull));
    });
  });

  group('VehicleRun.pointAt', () {
    DateTime at(int hour, int minute, [int second = 0]) =>
        DateTime.utc(2026, 11, 3, hour, minute, second);
    final run = VehicleRun([
      RunStop(
        id: 'a',
        name: 'A',
        departurePlanned: at(10, 0),
        position: const GeoPoint(51, 7),
      ),
      RunStop(
        id: 'b',
        name: 'B',
        arrivalPlanned: at(10, 10),
        departurePlanned: at(10, 12),
        position: const GeoPoint(51.1, 7.2),
      ),
      RunStop(id: 'c', name: 'C', arrivalPlanned: at(10, 20)),
    ]);

    test('between two stops, as far as the time has passed', () {
      final point = run.pointAt(at(10, 5))!;
      expect(point.latitude, closeTo(51.05, 1e-9));
      expect(point.longitude, closeTo(7.1, 1e-9));
    });

    test('on the stop while it stands there', () {
      expect(run.pointAt(at(10, 11)), const GeoPoint(51.1, 7.2));
    });

    test('nothing before the start or after the end', () {
      expect(run.pointAt(at(9, 59)), isNull);
      expect(run.pointAt(at(10, 30)), isNull);
    });

    test('without the next stop\'s position, the last known one', () {
      expect(run.pointAt(at(10, 15)), const GeoPoint(51.1, 7.2));
    });
  });
}
