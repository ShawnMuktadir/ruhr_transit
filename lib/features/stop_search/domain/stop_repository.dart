import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

abstract interface class StopRepository {
  /// Stops matching [query], best match first. No match is `Ok([])`, not
  /// an error.
  ///
  /// Starting a new search cancels the previous one on the same instance;
  /// the cancelled call completes with a `CancelledFailure`.
  ///
  /// With [includeAddresses], addresses and places are found too (for the
  /// trip planner); otherwise only stops.
  Future<Result<List<Stop>>> searchStops(
    String query, {
    bool includeAddresses = false,
  });

  /// The address (or stop) at a point, e.g. the user's location; `Ok(null)`
  /// when there is none.
  Future<Result<Stop?>> locationAt({
    required double latitude,
    required double longitude,
  });
}
