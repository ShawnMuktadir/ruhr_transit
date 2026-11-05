import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/current_location_finder.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';

/// The station where a ride starts, as a stop to walk to or show departures
/// of; null without its id or point. The station, not the platform: VRR
/// routes a walk only as far as the station anyway (checked live).
Stop? boardingStopOf(TransitLeg ride) {
  final id = ride.originId?.parentId ?? ride.originId?.id;
  final position = ride.origin.position;
  if (id == null || position == null) return null;
  return Stop(
    id: id,
    name: ride.origin.name,
    fullName: ride.origin.name,
    latitude: position.latitude,
    longitude: position.longitude,
  );
}

/// [journey] with the walk [route] to its first ride put in front, timed to
/// arrive when the ride leaves: its leave time, reminder and map then count
/// the walk. Unchanged when it does not start with a ride.
Journey withWalkToFirstRide(Journey journey, WalkLeg route) {
  final first = journey.legs.first;
  if (first is! TransitLeg) return journey;
  final arrive = first.origin.time;
  return Journey([
    WalkLeg(
      duration: route.duration,
      distanceMeters: route.distanceMeters,
      origin: TripStop(
        name: route.origin.name,
        plannedTime: arrive.subtract(route.duration),
        position: route.origin.position,
      ),
      destination: TripStop(
        name: first.origin.name,
        plannedTime: arrive,
        position: first.origin.position,
      ),
      steps: route.steps,
      stationPaths: route.stationPaths,
      path: route.path,
    ),
    ...journey.legs,
  ]);
}

/// How finding the way to a stop on foot ended. Sealed, so the UI handles
/// every case.
sealed class WalkToResult {
  const WalkToResult();
}

/// A journey of walking only, with its directions and path.
final class WalkFound extends WalkToResult {
  const WalkFound(this.journey);

  final Journey journey;
}

/// The user's location is not known; says why.
final class WalkNoLocation extends WalkToResult {
  const WalkNoLocation(this.problem);

  final HereResult problem;
}

/// No walk, or one too long to be meant: e.g. a favourite in another town.
final class WalkNotFound extends WalkToResult {
  const WalkNotFound();
}

final class WalkFailed extends WalkToResult {
  const WalkFailed(this.failure);

  final Failure failure;
}

/// The way on foot from where the user is to a stop. Only called on the
/// user's tap, as it may ask for the location permission.
class WalkToStop {
  const WalkToStop(this.finder, this._trips);

  final CurrentLocationFinder finder;
  final TripRepository _trips;

  /// A longer walk is no answer to "how do I get to this stop?".
  static const maxWalk = Duration(hours: 2);

  Future<WalkToResult> find(Stop target) async {
    final here = await finder.find();
    if (here is! HereFound) return WalkNoLocation(here);
    return switch (await _trips.walkRoute(from: here.stop, to: target)) {
      Ok(value: final journey?) when journey.duration <= maxWalk => WalkFound(
        journey,
      ),
      Ok() => const WalkNotFound(),
      Err(:final failure) => WalkFailed(failure),
    };
  }
}
