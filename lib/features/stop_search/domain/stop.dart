import 'package:ruhr_transit/core/domain/transport_mode.dart';

/// A public transport stop that departures can be requested for.
class Stop {
  const Stop({
    required this.id,
    required this.name,
    required this.fullName,
    required this.latitude,
    required this.longitude,
    this.locality,
    this.modes = const {},
  });

  /// Global stop ID (DHID), e.g. `de:05911:5194` for Bochum Hbf. Used as
  /// the key for departure requests.
  final String id;

  /// Name without the town, e.g. `Hbf`.
  final String name;

  /// Name including the town, e.g. `Bochum, Hbf`.
  final String fullName;

  /// Town or city the stop belongs to, e.g. `Bochum`.
  final String? locality;

  final double latitude;
  final double longitude;
  final Set<TransportMode> modes;

  /// Two stops are the same stop if they have the same global ID.
  @override
  bool operator ==(Object other) => other is Stop && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Stop($id, $fullName)';
}
