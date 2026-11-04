import 'dart:async';

import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

/// Hand-written fake: records every query and answers with [replies] in
/// order (the last one repeats), or waits for [pending] if set.
class FakeTripRepository implements TripRepository {
  final List<TripQuery> queries = [];
  List<Result<List<Journey>>> replies = [
    Ok([directS1, withWalk]),
  ];
  Completer<Result<List<Journey>>>? pending;

  /// What [walkRoute] answers; the targets asked for are recorded.
  Result<Journey?> walkReply = const Ok(null);
  final List<(Stop, Stop)> walks = [];

  @override
  Future<Result<Journey?>> walkRoute({
    required Stop from,
    required Stop to,
  }) async {
    walks.add((from, to));
    return walkReply;
  }

  /// Called on every query, before answering; tests change [replies] here.
  void Function()? onQuery;

  @override
  Future<Result<List<Journey>>> trips(TripQuery query) {
    queries.add(query);
    onQuery?.call();
    if (pending case final pending?) return pending.future;
    final index = queries.length - 1;
    return Future.value(replies[index.clamp(0, replies.length - 1)]);
  }
}

DateTime _utc(int hour, int minute) => DateTime.utc(2026, 11, 2, hour, minute);

/// S1 from Bochum Hbf, 3 minutes late, direct.
final directS1 = Journey([
  TransitLeg(
    line: 'S1',
    mode: TransportMode.suburbanTrain,
    direction: 'Dortmund Hbf',
    origin: TripStop(
      name: 'Bochum Hbf',
      plannedTime: _utc(7, 14),
      estimatedTime: _utc(7, 17),
      platform: '8',
      plannedPlatform: '8',
    ),
    destination: TripStop(
      name: 'Dortmund Hbf',
      plannedTime: _utc(7, 37),
      estimatedTime: _utc(7, 39),
    ),
    isRealtime: true,
  ),
]);

/// U35, a 4-minute walk, then a bus leaving right after the walk: no time
/// to spare.
final withWalk = Journey([
  TransitLeg(
    line: 'U35',
    mode: TransportMode.subway,
    direction: 'Herne Schloß Strünkede',
    origin: TripStop(name: 'Bochum Ruhr-Universität', plannedTime: _utc(7, 21)),
    destination: TripStop(
      name: 'Bochum Hbf',
      plannedTime: _utc(7, 31),
      platform: 'Gleis 3 (U)',
    ),
    intermediateStops: [
      TripStop(name: 'Bochum Gesundheitscampus', plannedTime: _utc(7, 22)),
      TripStop(
        name: 'Bochum Markstr.',
        plannedTime: _utc(7, 23),
        estimatedTime: _utc(7, 25),
        platform: '2',
      ),
    ],
    notices: const [lineNotice, liftNotice, rideNotice],
    // Matches u35Run in fake_vehicle_run_repository.dart.
    runKey: RunKey(
      lineId: 'bog:U35: :H:j26',
      tripCode: '1234',
      stopId: 'de:05911:5600:8:8',
      plannedDeparture: _utc(7, 21),
    ),
    originId: const StopRef('de:05911:5600:8:8', parentId: 'de:05911:5600'),
    destinationId: const StopRef(
      'de:05911:5194:3:3',
      parentId: 'de:05911:5194',
    ),
    isRealtime: true,
  ),
  WalkLeg(
    duration: const Duration(minutes: 4),
    distanceMeters: 183,
    origin: TripStop(name: 'Bochum Hbf', plannedTime: _utc(7, 31)),
    destination: TripStop(
      name: 'Bochum Hbf/Boulevard',
      plannedTime: _utc(7, 35),
    ),
    steps: const [
      WalkStep(
        turn: WalkTurn.alight,
        name: 'Ausstieg U-Bahn U35 rechts',
        distanceMeters: 0,
        duration: Duration.zero,
      ),
      WalkStep(
        turn: WalkTurn.straight,
        distanceMeters: 60,
        duration: Duration(seconds: 54),
      ),
      WalkStep(
        turn: WalkTurn.right,
        name: 'Südring',
        distanceMeters: 123,
        duration: Duration(seconds: 110),
      ),
    ],
    stationPaths: const [
      StationPath(kind: StationPathKind.elevator, levelFrom: -2, levelTo: 0),
    ],
  ),
  TransitLeg(
    line: '339',
    mode: TransportMode.bus,
    direction: 'Bochum Ruhr-Universität',
    origin: TripStop(name: 'Bochum Hbf/Boulevard', plannedTime: _utc(7, 35)),
    destination: TripStop(
      name: 'Bochum BP/Aral-Haus',
      plannedTime: _utc(7, 37),
    ),
    notes: const ['Umleitung wegen Baustelle'],
    isRealtime: true,
  ),
]);

/// Leaves after [withWalk]; what "later trips" finds.
final laterRe11 = Journey([
  TransitLeg(
    line: 'RE11',
    mode: TransportMode.train,
    direction: 'Kassel',
    origin: TripStop(name: 'Bochum Hbf', plannedTime: _utc(7, 50)),
    destination: TripStop(name: 'Dortmund Hbf', plannedTime: _utc(8, 3)),
  ),
]);

/// A station notice, as EFA sends for Bochum Hbf.
const liftNotice = TripNotice(
  id: 'VRR-de:05911:5194:31',
  kind: TripNoticeKind.facilities,
  title: 'Haltestelle Bochum Hbf: Aufzug außer Betrieb.',
  text:
      'An der Haltestelle Bochum Hbf ist der Aufzug zur Verteilerebene bis '
      'auf Weiteres außer Betrieb.',
);

/// A long-running, low-priority line notice.
const lineNotice = TripNotice(
  id: 'ems-50050',
  kind: TripNoticeKind.line,
  title: 'Haltestellenveränderungen durch Baumaßnahme',
  summary: 'Linien 345, 355 - Haltestellenveränderungen',
  text:
      'Linien 345, 355: Zwischen (H) Lessing-Schule und (H) Papenholz.\n'
      'Dauer: 08.06.26 bis 04.01.27',
  priority: TripNoticePriority.low,
);

/// About the ride itself, so a warning.
const rideNotice = TripNotice(
  id: 'DBProd-2711395',
  kind: TripNoticeKind.trip,
  title: 'Strecke zw. Bochum und Herne beeinträchtigt',
  text: 'Wegen eines Defekts an einem Zug kommt es zu Verspätungen.',
);
