import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

/// One departure from a stop, as shown on the departure board.
class Departure {
  const Departure({
    required this.line,
    required this.destination,
    required this.plannedTime,
    this.mode,
    this.estimatedTime,
    this.platform,
    this.plannedPlatform,
    this.isCancelled = false,
    this.notes = const [],
    this.runKey,
  });

  /// For asking VRR about delays; not saved with a stored board.
  final RunKey? runKey;

  /// The best known departure.
  DateTime get time => estimatedTime ?? plannedTime;

  /// Line as passengers know it, e.g. `RE16`, `U35`, `349`.
  final String line;

  /// Null when EFA sends a product class the app does not know.
  final TransportMode? mode;

  final String destination;

  /// Timetabled departure, in UTC like everything EFA sends.
  final DateTime plannedTime;

  /// Realtime prediction in UTC. Null when there is no realtime data, which
  /// is not the same as "on time".
  final DateTime? estimatedTime;

  /// Platform the vehicle actually leaves from, e.g. `3`, `Gleis 5 (U)`.
  final String? platform;

  /// Platform from the timetable.
  final String? plannedPlatform;

  final bool isCancelled;

  /// Realtime reasons for disruptions, e.g. "Verspätung eines vorausfahrenden
  /// Zuges". Only in German; EFA does not translate them.
  final List<String> notes;

  /// Difference between estimate and plan; null without realtime data.
  /// Negative when the vehicle leaves early.
  Duration? get delay => estimatedTime?.difference(plannedTime);

  bool get platformChanged =>
      platform != null &&
      plannedPlatform != null &&
      platform != plannedPlatform;

  @override
  String toString() => 'Departure($line → $destination, $plannedTime)';
}

/// [departures] in the order they actually leave: by [Departure.time], so a
/// train 3 hours late comes after the S-Bahn leaving now. EFA sends them by
/// planned time. Equal times keep their order.
List<Departure> inDepartureOrder(Iterable<Departure> departures) {
  final indexed = departures.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.time.compareTo(b.$2.time);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return [for (final (_, departure) in indexed) departure];
}
