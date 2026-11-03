import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

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
  /// attached to several legs): warnings first, background last, otherwise
  /// in travel order.
  List<TripNotice> get notices {
    final seen = <String>{};
    final unique = [
      for (final leg in legs)
        for (final notice in leg.notices)
          if (seen.add(notice.id)) notice,
    ];
    return [
      for (final severity in TripNoticeSeverity.values)
        ...unique.where((notice) => notice.severity == severity),
    ];
  }

  /// Whether any notice is a warning, see [TripNoticeSeverity.warning].
  bool get hasWarning =>
      notices.any((notice) => notice.severity == TripNoticeSeverity.warning);

  /// No ride has live data from VRR: every time is the timetable's. True
  /// for most journeys outside the VRR area.
  bool get isTimetableOnly {
    final rides = legs.whereType<TransitLeg>();
    return rides.isNotEmpty && rides.every((ride) => !ride.isRealtime);
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
    this.position,
  });

  /// Stop name including the town, e.g. `Bochum Hbf`.
  final String name;

  /// From the timetable, in UTC.
  final DateTime plannedTime;

  /// Realtime prediction in UTC; null without realtime data.
  final DateTime? estimatedTime;

  final String? platform;
  final String? plannedPlatform;

  /// Where the stop (or address) is; null when EFA sends no point.
  final GeoPoint? position;

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
    this.path = const [],
  });

  final TripStop origin;
  final TripStop destination;

  /// The way the vehicle or walker takes (`coords`), for the map; empty
  /// when EFA sends none.
  final List<GeoPoint> path;

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
    this.runKey,
    this.originId,
    this.destinationId,
    this.isRealtime = false,
    this.transferSteps = const [],
    this.transferPaths = const [],
    super.notices,
    super.path,
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

  /// For requesting the vehicle's whole run; null when EFA sent no line id
  /// or trip code.
  final RunKey? runKey;

  /// VRR has live data for this ride (`realtimeStatus: MONITORED`).
  final bool isRealtime;

  /// The way from getting off to boarding the next ride when no walk leg
  /// lies in between: EFA puts a change inside a station on the ride
  /// before it. Empty after the last ride.
  final List<WalkStep> transferSteps;

  /// Lifts, escalators and stairs on that way.
  final List<StationPath> transferPaths;

  /// Where the user boards and gets off, down to the platform, to find
  /// them in the whole run.
  final StopRef? originId;
  final StopRef? destinationId;
}

/// Walking between stops, e.g. from the U-Bahn to a bus stop.
final class WalkLeg extends Leg {
  const WalkLeg({
    required this.duration,
    required super.origin,
    required super.destination,
    this.distanceMeters,
    this.steps = const [],
    this.stationPaths = const [],
    super.notices,
    super.path,
  });

  /// EFA's walking time, which may be shorter than the gap to the next leg.
  final Duration duration;

  final int? distanceMeters;

  /// Turn by turn, as EFA describes the way (`pathDescriptions`); empty
  /// when it sends none.
  final List<WalkStep> steps;

  /// Lifts, escalators and stairs on the way in or out of a stop
  /// (`footPathInfo`).
  final List<StationPath> stationPaths;
}

/// How a [WalkStep] begins, from EFA's `turnDirection` and `manoeuvre`.
enum WalkTurn {
  straight,
  slightLeft,
  left,
  sharpLeft,
  slightRight,
  right,
  sharpRight,
  uTurn,

  /// Getting on a vehicle, e.g. "Einstieg Zug RE 6".
  board,

  /// Getting off a vehicle.
  alight,
  unknown,
}

/// One step of a walk: "right into Südring, 182 m".
class WalkStep {
  const WalkStep({
    required this.turn,
    required this.distanceMeters,
    required this.duration,
    this.name,
  });

  final WalkTurn turn;

  /// The street or way, in German as VRR sends it ("Südring",
  /// "Treppe aufwärts zur Ebene 1"); null for a generic footpath.
  final String? name;

  final int distanceMeters;
  final Duration duration;
}

enum StationPathKind { elevator, escalator, stairs, other }

/// A lift, escalator or stairs between two levels of a stop.
class StationPath {
  const StationPath({required this.kind, this.levelFrom, this.levelTo});

  final StationPathKind kind;
  final int? levelFrom;
  final int? levelTo;
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

/// EFA's `priority`, which has five steps: `veryLow`, `low`, `normal`,
/// `high`, `veryHigh`. Live data so far has only shown `normal` and
/// `veryLow`.
enum TripNoticePriority { low, normal, high }

/// How a notice is shown, derived only from what VRR sends: its priority
/// and its type. VRR does not mark how serious a notice is otherwise.
enum TripNoticeSeverity {
  /// High priority, or about the ride itself (`tripMessage`): a disrupted
  /// route, a train defect, no boarding aid.
  warning,

  /// Normal priority about a stop or line, e.g. a lift out of order.
  note,

  /// Low priority, e.g. a stop change that has lasted for months.
  background,
}

/// A notice from VRR about a stop, a line or a ride. German only.
class TripNotice {
  const TripNotice({
    required this.id,
    required this.kind,
    required this.title,
    this.summary,
    this.text = '',
    this.priority = TripNoticePriority.normal,
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

  final TripNoticePriority priority;

  TripNoticeSeverity get severity => switch ((priority, kind)) {
    (TripNoticePriority.high, _) => TripNoticeSeverity.warning,
    (TripNoticePriority.low, _) => TripNoticeSeverity.background,
    (_, TripNoticeKind.trip) => TripNoticeSeverity.warning,
    _ => TripNoticeSeverity.note,
  };

  @override
  String toString() => 'TripNotice($id, $title)';
}

/// A stop's EFA ids: the platform-level id and its station.
class StopRef {
  const StopRef(this.id, {this.parentId});

  /// e.g. `de:05911:5194:91:3`.
  final String id;

  /// e.g. `de:05911:5194`.
  final String? parentId;
}
