/// The device's current location, read once when the user asks for it.
abstract interface class LocationSource {
  /// Asks for the permission if needed, then reads the location once.
  Future<LocationResult> currentLocation();

  /// Opens the app's system settings, where a permanently denied
  /// permission can be granted.
  Future<void> openAppSettings();

  /// Opens the system location settings, where location can be turned on.
  Future<void> openLocationSettings();
}

/// Sealed, so the UI must handle every way reading the location can end.
sealed class LocationResult {
  const LocationResult();
}

final class Located extends LocationResult {
  const Located({
    required this.latitude,
    required this.longitude,
    this.isApproximate = false,
  });

  final double latitude;
  final double longitude;

  /// The user granted only approximate location (Android 12+), which can be
  /// off by about 2 km: more than the search radius.
  final bool isApproximate;
}

/// Location is turned off on the device.
final class LocationOff extends LocationResult {
  const LocationOff();
}

final class LocationPermissionDenied extends LocationResult {
  const LocationPermissionDenied({required this.permanently});

  /// Android no longer shows the permission dialog; only the app settings
  /// can grant it now.
  final bool permanently;
}

/// No position arrived in time, e.g. indoors without network location.
final class LocationTimeout extends LocationResult {
  const LocationTimeout();
}
