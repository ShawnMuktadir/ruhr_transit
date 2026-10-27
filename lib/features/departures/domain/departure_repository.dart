import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';

abstract interface class DepartureRepository {
  /// The next departures from the stop with global ID [stopId], soonest
  /// first. No departures is `Ok([])`, not an error.
  ///
  /// Starting a new request cancels the previous one on the same instance;
  /// the cancelled call completes with a `CancelledFailure`.
  Future<Result<List<Departure>>> departuresAt(String stopId);
}
