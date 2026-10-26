import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

abstract interface class StopRepository {
  /// Stops matching [query], best match first. No match is `Ok([])`, not
  /// an error.
  ///
  /// Starting a new search cancels the previous one on the same instance;
  /// the cancelled call completes with a `CancelledFailure`.
  Future<Result<List<Stop>>> searchStops(String query);
}
