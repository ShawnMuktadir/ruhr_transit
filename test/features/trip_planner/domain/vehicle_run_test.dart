import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

void main() {
  DateTime at(int hour, int minute) => DateTime.utc(2026, 11, 2, hour, minute);

  /// A -> B -> C. B: arrives 10:05, departs 10:07.
  final run = VehicleRun([
    RunStop(id: 'a:1', parentId: 'a', name: 'A', departurePlanned: at(10, 0)),
    RunStop(
      id: 'b:1',
      parentId: 'b',
      name: 'B',
      arrivalPlanned: at(10, 5),
      departurePlanned: at(10, 7),
    ),
    RunStop(id: 'c:1', parentId: 'c', name: 'C', arrivalPlanned: at(10, 12)),
  ]);

  group('positionAt', () {
    test('before the first departure the run has not started', () {
      expect(run.positionAt(at(9, 59)), isA<RunNotStarted>());
    });

    test('between two stops after leaving one', () {
      expect(
        run.positionAt(at(10, 2)),
        isA<RunBetween>().having((p) => p.from, 'from', 0),
      );
      expect(
        run.positionAt(at(10, 9)),
        isA<RunBetween>().having((p) => p.to, 'to', 2),
      );
    });

    test('at a stop between arrival and departure', () {
      expect(
        run.positionAt(at(10, 5)),
        isA<RunAtStop>().having((p) => p.index, 'index', 1),
      );
      expect(
        run.positionAt(at(10, 6)),
        isA<RunAtStop>().having((p) => p.index, 'index', 1),
      );
    });

    test('"07:21 arrival, 07:21 departure" is at the stop for that minute', () {
      final quick = VehicleRun([
        RunStop(id: 'a', name: 'A', departurePlanned: at(10, 0)),
        RunStop(
          id: 'b',
          name: 'B',
          arrivalPlanned: at(10, 5),
          departurePlanned: at(10, 5),
        ),
        RunStop(id: 'c', name: 'C', arrivalPlanned: at(10, 9)),
      ]);

      expect(quick.positionAt(at(10, 5)), isA<RunAtStop>());
      expect(
        quick.positionAt(at(10, 5).add(const Duration(seconds: 59))),
        isA<RunAtStop>(),
      );
      expect(quick.positionAt(at(10, 6)), isA<RunBetween>());
    });

    test('from the last arrival on the run has ended', () {
      expect(run.positionAt(at(10, 12)), isA<RunEnded>());
      expect(run.positionAt(at(11, 0)), isA<RunEnded>());
    });

    test('uses live times over the timetable', () {
      final late = VehicleRun([
        RunStop(
          id: 'a:1',
          name: 'A',
          departurePlanned: at(10, 0),
          departureEstimated: at(10, 4),
        ),
        RunStop(
          id: 'b:1',
          name: 'B',
          arrivalPlanned: at(10, 5),
          arrivalEstimated: at(10, 9),
        ),
      ], isRealtime: true);

      // Planned it would have left; it is still waiting at A.
      expect(late.positionAt(at(10, 2)), isA<RunNotStarted>());
      expect(late.positionAt(at(10, 6)), isA<RunBetween>());
    });
  });

  group('indexOf', () {
    test('finds the platform, else the station', () {
      expect(run.indexOf('b:1'), 1);
      // Another platform of the same station.
      expect(run.indexOf('b:7', parentId: 'b'), 1);
      expect(run.indexOf('x:1', parentId: 'x'), isNull);
      expect(run.indexOf('x:1'), isNull);
    });
  });
}
