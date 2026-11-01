import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';

/// Sealed, so the page's `switch` must render every state.
sealed class NearbyStopsState {
  const NearbyStopsState();
}

/// Waiting for the permission dialog or a position fix.
final class NearbyLocating extends NearbyStopsState {
  const NearbyLocating();
}

/// Position known, waiting for EFA.
final class NearbyLoading extends NearbyStopsState {
  const NearbyLoading();
}

/// The stops around the user, closest first; possibly none.
final class NearbyLoaded extends NearbyStopsState {
  const NearbyLoaded(this.stops, {this.isApproximate = false});

  final List<NearbyStop> stops;

  /// The position was only approximate, so [stops] may not be the closest.
  final bool isApproximate;
}

/// The location could not be read. Never a [Located].
final class NearbyLocationProblem extends NearbyStopsState {
  const NearbyLocationProblem(this.problem);

  final LocationResult problem;
}

/// The location was read, but loading the stops failed.
final class NearbyFailed extends NearbyStopsState {
  const NearbyFailed(this.failure);

  final Failure failure;
}
