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

  /// VRR's notices for this journey, each once (the same notice is often
  /// attached to several legs), the important ones first.
  List<TripNotice> get notices {
    final seen = <String>{};
    final unique = [
      for (final leg in legs)
        for (final notice in leg.notices)
          if (seen.add(notice.id)) notice,
    ];
    return [
      ...unique.where((notice) => !notice.isLowPriority),
      ...unique.where((notice) => notice.isLowPriority),
    ];
  }

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
  const Leg({
    required this.origin,
    required this.destination,
    this.notices = const [],
  });

  final TripStop origin;
  final TripStop destination;

  /// VRR's notices for this leg, e.g. a lift out of order at a stop.
  final List<TripNotice> notices;
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
    this.intermediateStops = const [],
    super.notices,
  });

  /// Line as passengers know it, e.g. `U35`, `RE11`.
  final String line;

  /// Null when EFA sends a product class the app does not know.
  final TransportMode? mode;

  /// Final stop of the line, as shown on the vehicle.
  final String direction;

  /// Realtime reasons for disruptions, in German.
  final List<String> notes;

  /// The stops between [origin] and [destination], in order. Empty for a
  /// ride without stops in between.
  final List<TripStop> intermediateStops;
}

/// Walking between stops, e.g. from the U-Bahn to a bus stop.
final class WalkLeg extends Leg {
  const WalkLeg({
    required this.duration,
    required super.origin,
    required super.destination,
    this.distanceMeters,
    super.notices,
  });

  /// EFA's walking time, which may be shorter than the gap to the next leg.
  final Duration duration;

  final int? distanceMeters;
}

/// What a notice is about, from EFA's `infos[].type`.
enum TripNoticeKind {
  /// `infrastructure`: a lift or escalator at a stop out of order.
  facilities,

  /// `stopInfo`: a stop moved or closed.
  stop,

  /// `lineInfo`: diversions or changes on a line.
  line,

  /// `tripMessage`: about this particular ride, e.g. no boarding aid.
  trip,

  /// A type the app does not know yet.
  other,
}

/// A notice from VRR about a stop, a line or a ride. German only.
class TripNotice {
  const TripNotice({
    required this.id,
    required this.kind,
    required this.title,
    this.summary,
    this.text = '',
    this.isLowPriority = false,
  });

  /// EFA's id, the same on every leg the notice is attached to.
  final String id;

  final TripNoticeKind kind;

  /// Short headline, e.g. "Haltestelle Bochum Hbf: Aufzug außer Betrieb."
  final String title;

  /// Which lines and stops are affected, e.g. "Linie U35 - (H) Bochum,
  /// Ruhr-Universität"; null when EFA sends none.
  final String? summary;

  /// The full text as plain text; may be empty.
  final String text;

  /// EFA's priority `low` or `veryLow`, e.g. long-running stop changes.
  final bool isLowPriority;

  @override
  String toString() => 'TripNotice($id, $title)';
}
