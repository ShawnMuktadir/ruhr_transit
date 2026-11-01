import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';

abstract interface class NearbyStopsRepository {
  /// Stops within [radiusMeters] of the given point, closest first. No stop
  /// is `Ok([])`, not an error.
  ///
  /// Starting a new request cancels the previous one on the same instance;
  /// the cancelled call completes with a `CancelledFailure`.
  Future<Result<List<NearbyStop>>> stopsNear({
    required double latitude,
    required double longitude,
  });

  /// How far [stopsNear] looks.
  static const radiusMeters = 1000;
}
