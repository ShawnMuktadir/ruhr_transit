import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';

/// How finding the user's location as a start ended. Sealed, so the form
/// handles every case.
sealed class HereResult {
  const HereResult();
}

/// The address (or stop) where the user is.
final class HereFound extends HereResult {
  const HereFound(this.stop);

  final Stop stop;
}

final class HereDenied extends HereResult {
  const HereDenied({required this.permanently});

  /// Android no longer asks; only the app settings can allow it.
  final bool permanently;
}

/// Location is turned off on the phone.
final class HereLocationOff extends HereResult {
  const HereLocationOff();
}

/// No position arrived in time.
final class HereNoPosition extends HereResult {
  const HereNoPosition();
}

/// VRR knows no address or stop at the position.
final class HereNothingThere extends HereResult {
  const HereNothingThere();
}

/// The lookup failed, e.g. without internet.
final class HereFailed extends HereResult {
  const HereFailed(this.failure);

  final Failure failure;
}

/// Turns the phone's position into a start for the planner: reads the
/// location (asking for the permission if needed; only called on the
/// user's tap) and asks VRR for the address there.
class CurrentLocationFinder {
  const CurrentLocationFinder(this._location, this._stops);

  final LocationSource _location;
  final StopRepository _stops;

  Future<HereResult> find() async {
    switch (await _location.currentLocation()) {
      case LocationOff():
        return const HereLocationOff();
      case LocationPermissionDenied(:final permanently):
        return HereDenied(permanently: permanently);
      case LocationTimeout():
        return const HereNoPosition();
      case Located(:final latitude, :final longitude):
        return switch (await _stops.locationAt(
          latitude: latitude,
          longitude: longitude,
        )) {
          Ok(value: final stop?) => HereFound(stop),
          Ok() => const HereNothingThere(),
          Err(:final failure) => HereFailed(failure),
        };
    }
  }

  Future<void> openAppSettings() => _location.openAppSettings();

  Future<void> openLocationSettings() => _location.openLocationSettings();
}
