import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/request_result.dart';
import 'package:ruhr_transit/features/departures/data/departure_cache.dart';
import 'package:ruhr_transit/features/departures/data/departure_mapper.dart';
import 'package:ruhr_transit/features/departures/data/efa_departure_remote_source.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';

class DepartureRepositoryImpl implements DepartureRepository {
  DepartureRepositoryImpl(
    this._remote,
    this._cache, {
    DateTime Function() now = DateTime.now,
    this.onBoardFetched,
  }) : _now = now;

  final EfaDepartureRemoteSource _remote;
  final DepartureCache _cache;
  final DateTime Function() _now;

  /// Told about every fetched board, e.g. to update the home-screen widget.
  /// Keeps the repository unaware of who listens.
  final Future<void> Function(String stopId, DepartureBoard board)?
  onBoardFetched;

  /// A second refresh replaces the first.
  final _latest = LatestRequest();

  @override
  Future<Result<DepartureBoard>> departuresAt(String stopId) => _latest.run(
    (cancelToken) => requestResult(() async {
      final json = await _remote.departuresAt(stopId, cancelToken: cancelToken);
      final board = DepartureBoard(
        mapDepartureMonitorResponse(json),
        fetchedAt: _now().toUtc(),
      );
      // Not awaited: the board should not wait for storage, and a full or
      // broken storage must not turn a good answer into an error.
      _inBackground('save', _cache.write(stopId, board));
      if (onBoardFetched case final notify?) {
        _inBackground('pass on', notify(stopId, board));
      }
      return board;
    }),
  );

  void _inBackground(String action, Future<void> work) => unawaited(
    work.catchError((Object e) {
      debugPrint('Could not $action departure board: $e');
    }),
  );

  @override
  Future<DepartureBoard?> lastBoard(String stopId) async {
    try {
      return await _cache.read(stopId);
    } on Exception catch (e) {
      // Only ever a fallback: without storage there is just nothing saved.
      debugPrint('Could not read departure board: $e');
      return null;
    }
  }
}
