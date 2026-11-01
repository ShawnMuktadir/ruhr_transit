import 'package:ruhr_transit/core/domain/transport_mode.dart';

/// One way from A to B: legs in travel order, possibly with walks between.
class Journey {
  Journey(List<Leg> legs) : legs = List.unmodifiable(legs) {
    if (legs.isEmpty) throw ArgumentError.value(legs, 'legs', 'is empty');
  }

  final List<Leg> legs;

  TripStop get departure => legs.first.origin;
  TripStop get arrival => legs.last.destination;

  /// From the expected departure to the expected arrival, so delays count.
  Duration get duration => arrival.time.difference(departure.time);

  /// Changes between vehicles; walks are not counted as rides.
  int get transfers {
    final rides = legs.whereType<TransitLeg>().length;
    return rides > 1 ? rides - 1 : 0;
  }

  @override
  String toString() =>
      'Journey(${departure.time} → ${arrival.time}, ${legs.length} legs)';
}

/// Where a leg starts or ends.
class TripStop {
  const TripStop({
    required this.name,
    required this.plannedTime,
    this.estimatedTime,
    this.platform,
    this.plannedPlatform,
  });

  /// Stop name including the town, e.g. `Bochum Hbf`.
  final String name;

  /// From the timetable, in UTC.
  final DateTime plannedTime;

  /// Realtime prediction in UTC; null without realtime data.
  final DateTime? estimatedTime;

  final String? platform;
  final String? plannedPlatform;

  /// The best known time. With delays, EFA plans connections from the
  /// estimates, so planned times of different legs may not fit together.
  DateTime get time => estimatedTime ?? plannedTime;

  /// Null without realtime data; negative when early.
  Duration? get delay => estimatedTime?.difference(plannedTime);

  bool get platformChanged =>
      platform != null &&
      plannedPlatform != null &&
      platform != plannedPlatform;
}

/// Sealed, so the UI must draw both kinds of leg.
sealed class Leg {
  const Leg({required this.origin, required this.destination});

  final TripStop origin;
  final TripStop destination;
}

/// A ride on a line.
final class TransitLeg extends Leg {
  const TransitLeg({
    required this.line,
    required this.direction,
    required super.origin,
    required super.destination,
    this.mode,
    this.notes = const [],
  });

  /// Line as passengers know it, e.g. `U35`, `RE11`.
  final String line;

  /// Null when EFA sends a product class the app does not know.
  final TransportMode? mode;

  /// Final stop of the line, as shown on the vehicle.
  final String direction;

  /// Realtime reasons for disruptions, in German.
  final List<String> notes;
}

/// Walking between stops, e.g. from the U-Bahn to a bus stop.
final class WalkLeg extends Leg {
  const WalkLeg({
    required this.duration,
    required super.origin,
    required super.destination,
    this.distanceMeters,
  });

  /// EFA's walking time, which may be shorter than the gap to the next leg.
  final Duration duration;

  final int? distanceMeters;
}
