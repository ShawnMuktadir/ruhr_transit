import 'dart:async';

import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';

/// Hand-written fake: every call is recorded and stays pending until the
/// test completes it, unless [autoReply] is set.
///
/// Tests reply with plain departure lists; the fake wraps them in a board
/// fetched at [fetchedAt].
class FakeDepartureRepository implements DepartureRepository {
  final List<String> stopIds = [];
  final List<Completer<Result<DepartureBoard>>> _pending = [];

  /// When set, calls complete immediately with this result instead.
  Result<List<Departure>>? autoReply;

  /// Fetch time of every board this fake returns.
  DateTime fetchedAt = boardTime;

  /// What [lastBoard] returns.
  DepartureBoard? savedBoard;

  /// When set, [lastBoard] waits for this instead of returning [savedBoard].
  Completer<DepartureBoard?>? pendingLastBoard;

  @override
  Future<Result<DepartureBoard>> departuresAt(String stopId) {
    stopIds.add(stopId);
    if (autoReply case final reply?) return Future.value(_toBoard(reply));
    final completer = Completer<Result<DepartureBoard>>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<DepartureBoard?> lastBoard(String stopId) async =>
      pendingLastBoard?.future ?? savedBoard;

  /// Answers the [index]-th call (0 = first call made).
  void complete(int index, Result<List<Departure>> result) =>
      _pending[index].complete(_toBoard(result));

  Result<DepartureBoard> _toBoard(Result<List<Departure>> result) =>
      switch (result) {
        Ok(value: final departures) => Ok(
          DepartureBoard(departures, fetchedAt: fetchedAt),
        ),
        Err(:final failure) => Err(failure),
      };
}

/// When the sample boards below were fetched: shortly before [delayedRe16]
/// leaves.
final boardTime = DateTime.utc(2026, 10, 25, 17, 2);

/// 12 minutes late, with a realtime note.
final delayedRe16 = Departure(
  line: 'RE16',
  mode: TransportMode.train,
  destination: 'Essen Hauptbahnhof',
  plannedTime: DateTime.utc(2026, 10, 25, 17, 13),
  estimatedTime: DateTime.utc(2026, 10, 25, 17, 25),
  platform: '3',
  plannedPlatform: '3',
  notes: const ['Vorfahrt eines anderen Zuges'],
);

final cancelledRe11 = Departure(
  line: 'RE11',
  mode: TransportMode.train,
  destination: 'Kassel Bahnhof Wilhelmshöhe',
  plannedTime: DateTime.utc(2026, 10, 25, 17, 24),
  platform: '5',
  plannedPlatform: '5',
  isCancelled: true,
);

/// On time, but leaves from another platform than planned.
final movedU35 = Departure(
  line: 'U35',
  mode: TransportMode.subway,
  destination: 'Bochum Hustadt (TQ)',
  plannedTime: DateTime.utc(2026, 10, 25, 17, 35),
  estimatedTime: DateTime.utc(2026, 10, 25, 17, 35),
  platform: 'Gleis 3 (U)',
  plannedPlatform: 'Gleis 4 (U)',
);
