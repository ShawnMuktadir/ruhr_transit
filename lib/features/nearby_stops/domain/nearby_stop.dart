import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// A stop and how far it is from where the user is.
class NearbyStop {
  const NearbyStop(this.stop, {required this.distanceMeters});

  final Stop stop;

  /// Straight-line distance as EFA reports it, not the walking distance.
  final int distanceMeters;

  @override
  String toString() => 'NearbyStop(${stop.fullName}, $distanceMeters m)';
}
