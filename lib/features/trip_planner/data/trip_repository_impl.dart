import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/request_result.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_trip_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';

class TripRepositoryImpl implements TripRepository {
  TripRepositoryImpl(this._remote);

  final EfaTripRemoteSource _remote;

  /// A new search replaces the one before.
  final _latest = LatestRequest();

  @override
  Future<Result<List<Journey>>> trips(TripQuery query) async {
    final result = await _latest.run(
      (cancelToken) => requestResult(() async {
        final json = await _remote.trips(query, cancelToken: cancelToken);
        return mapTripResponse(json);
      }),
    );
    switch (result) {
      // Outside NRW the service is sometimes very slow; it says so.
      case Err(failure: TimeoutFailure()) when query.isOutsideNrw:
        return const Err(OutsideNrwFailure());
      case Err(failure: ParseFailure(:final message)):
        debugPrint('Could not read the trips: $message');
      case _:
    }
    return result;
  }

  @override
  Future<Result<Journey?>> walkRoute({required Stop from, required Stop to}) =>
      requestResult(() async {
        final json = await _remote.walk(fromId: from.id, toId: to.id);
        final walks = mapTripResponse(
          json,
        ).where((journey) => journey.legs.every((leg) => leg is WalkLeg));
        return walks.firstOrNull;
      });
}
