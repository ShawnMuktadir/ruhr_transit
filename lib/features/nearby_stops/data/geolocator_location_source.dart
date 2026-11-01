import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';

/// [LocationSource] through the geolocator plugin. The only file that
/// knows about geolocator.
class GeolocatorLocationSource implements LocationSource {
  const GeolocatorLocationSource();

  /// Long enough for a first fix outdoors, short enough that the user is
  /// not left waiting indoors.
  static const timeLimit = Duration(seconds: 15);

  @override
  Future<bool> hasPermission() async =>
      switch (await Geolocator.checkPermission()) {
        LocationPermission.whileInUse || LocationPermission.always => true,
        _ => false,
      };

  @override
  Future<LocationResult> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationOff();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied || LocationPermission.unableToDetermine:
        return const LocationPermissionDenied(permanently: false);
      case LocationPermission.deniedForever:
        return const LocationPermissionDenied(permanently: true);
      case LocationPermission.whileInUse || LocationPermission.always:
        break;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        // The default (best) accuracy, although ~100 m would do: lower
        // accuracies rely on network location, and with Google's "Location
        // Accuracy" off they never got a fix on the test emulator. Best
        // can use GPS; Play Services may ask once to turn that setting on,
        // and declining still gives a position.
        locationSettings: const LocationSettings(timeLimit: timeLimit),
      );
      final accuracy = await Geolocator.getLocationAccuracy();
      return Located(
        latitude: position.latitude,
        longitude: position.longitude,
        isApproximate: accuracy == LocationAccuracyStatus.reduced,
      );
    } on TimeoutException {
      return const LocationTimeout();
    } on LocationServiceDisabledException {
      // Turned off between the check above and the fix.
      return const LocationOff();
    }
  }

  @override
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
