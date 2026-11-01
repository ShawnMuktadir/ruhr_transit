import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_error_mapper.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
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
  }) : _now = now;

  final EfaDepartureRemoteSource _remote;
  final DepartureCache _cache;
  final DateTime Function() _now;

  /// The request that is still running, if any. Holding this makes the
  /// repository stateful, so it is registered as a factory: one per page.
  CancelToken? _inFlight;

  @override
  Future<Result<DepartureBoard>> departuresAt(String stopId) async {
    // A second refresh replaces the first; only the newest answer matters.
    _inFlight?.cancel();
    final cancelToken = _inFlight = CancelToken();
    try {
      final json = await _remote.departuresAt(stopId, cancelToken: cancelToken);
      final board = DepartureBoard(
        mapDepartureMonitorResponse(json),
        fetchedAt: _now().toUtc(),
      );
      // Not awaited: the board should not wait for storage, and a full or
      // broken storage must not turn a good answer into an error.
      unawaited(
        _cache.write(stopId, board).catchError((Object e) {
          debugPrint('Could not save departure board: $e');
        }),
      );
      return Ok(board);
    } on DioException catch (e) {
      return Err(failureFromDioException(e));
    } on EfaServerException catch (e) {
      return Err(ServerFailure(code: e.code, message: e.message));
    } on FormatException catch (e) {
      return Err(ParseFailure(e.message));
    } finally {
      if (identical(_inFlight, cancelToken)) _inFlight = null;
    }
  }

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
