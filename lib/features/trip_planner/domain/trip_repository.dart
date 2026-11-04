import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';

abstract interface class TripRepository {
  /// Journeys for [query], earliest first. No journey is `Ok([])`, not an
  /// error.
  ///
  /// Starting a new request cancels the previous one on the same instance;
  /// the cancelled call completes with a `CancelledFailure`.
  Future<Result<List<Journey>>> trips(TripQuery query);

  /// The way on foot, or `Ok(null)` when there is none.
  Future<Result<Journey?>> walkRoute({required Stop from, required Stop to});
}
