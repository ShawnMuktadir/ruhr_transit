import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';

/// Answers every request with [reply] and records the keys asked for.
class FakeVehicleRunRepository implements VehicleRunRepository {
  FakeVehicleRunRepository([Result<VehicleRun>? reply])
    : reply = reply ?? Ok(u35Run);

  Result<VehicleRun> reply;
  final List<RunKey> keys = [];

  @override
  Future<Result<VehicleRun>> run(RunKey key) async {
    keys.add(key);
    return reply;
  }
}

DateTime _utc(int hour, int minute) => DateTime.utc(2026, 11, 2, hour, minute);

/// The whole run of the U35 in `withWalk`: it starts two stops before the
/// user boards at Bochum Ruhr-Universität (07:21) and ends one stop after
/// they get off at Bochum Hbf (07:31).
final u35Run = VehicleRun([
  RunStop(
    id: 'de:05911:5111:1:1',
    parentId: 'de:05911:5111',
    name: 'Bochum Hustadt',
    departurePlanned: _utc(7, 17),
  ),
  RunStop(
    id: 'de:05911:5112:1:1',
    parentId: 'de:05911:5112',
    name: 'Bochum Lennershof',
    arrivalPlanned: _utc(7, 19),
    departurePlanned: _utc(7, 19),
  ),
  RunStop(
    id: 'de:05911:5600:8:8',
    parentId: 'de:05911:5600',
    name: 'Bochum Ruhr-Universität',
    arrivalPlanned: _utc(7, 21),
    departurePlanned: _utc(7, 21),
    platform: '08',
  ),
  RunStop(
    id: 'de:05911:5601:1:1',
    parentId: 'de:05911:5601',
    name: 'Bochum Gesundheitscampus',
    arrivalPlanned: _utc(7, 22),
    departurePlanned: _utc(7, 22),
  ),
  RunStop(
    id: 'de:05911:5602:1:2',
    parentId: 'de:05911:5602',
    name: 'Bochum Markstr.',
    arrivalPlanned: _utc(7, 23),
    arrivalEstimated: _utc(7, 25),
    departurePlanned: _utc(7, 23),
    departureEstimated: _utc(7, 25),
    platform: '2',
  ),
  RunStop(
    id: 'de:05911:5194:3:3',
    parentId: 'de:05911:5194',
    name: 'Bochum Hbf',
    arrivalPlanned: _utc(7, 31),
    departurePlanned: _utc(7, 32),
    platform: 'Gleis 3 (U)',
  ),
  RunStop(
    id: 'de:05911:5195:1:1',
    parentId: 'de:05911:5195',
    name: 'Bochum Rathaus (Süd)',
    arrivalPlanned: _utc(7, 34),
  ),
], isRealtime: true);
