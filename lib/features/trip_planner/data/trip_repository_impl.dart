import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_error_mapper.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_trip_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';

class TripRepositoryImpl implements TripRepository {
  TripRepositoryImpl(this._remote);

  final EfaTripRemoteSource _remote;

  /// The request that is still running, if any. Holding this makes the
  /// repository stateful, so it is registered as a factory: one per page.
  CancelToken? _inFlight;

  @override
  Future<Result<List<Journey>>> trips(TripQuery query) async {
    // A new search replaces the one before; only the newest answer matters.
    _inFlight?.cancel();
    final cancelToken = _inFlight = CancelToken();
    try {
      final json = await _remote.trips(query, cancelToken: cancelToken);
      return Ok(mapTripResponse(json));
    } on DioException catch (e) {
      final failure = failureFromDioException(e);
      return Err(
        failure is TimeoutFailure && query.isOutsideNrw
            ? const OutsideNrwFailure()
            : failure,
      );
    } on EfaServerException catch (e) {
      return Err(ServerFailure(code: e.code, message: e.message));
    } on FormatException catch (e) {
      debugPrint('Could not read the trips: ${e.message}');
      return Err(ParseFailure(e.message));
    } finally {
      if (identical(_inFlight, cancelToken)) _inFlight = null;
    }
  }

  @override
  Future<Result<Journey?>> walkRoute({
    required Stop from,
    required Stop to,
  }) async {
    try {
      final json = await _remote.walk(fromId: from.id, toId: to.id);
      final walks = mapTripResponse(
        json,
      ).where((journey) => journey.legs.every((leg) => leg is WalkLeg));
      return Ok(walks.firstOrNull);
    } on DioException catch (e) {
      return Err(failureFromDioException(e));
    } on EfaServerException catch (e) {
      return Err(ServerFailure(code: e.code, message: e.message));
    } on FormatException catch (e) {
      return Err(ParseFailure(e.message));
    }
  }
}
