import 'package:ruhr_transit/core/domain/geo_point.dart';

/// What identifies one vehicle's run, so its whole stop sequence can be
/// requested: the line, EFA's trip code, and one stop with its planned
/// departure. All four come with every ride in a trip response.
class RunKey {
  const RunKey({
    required this.lineId,
    required this.tripCode,
    required this.stopId,
    required this.plannedDeparture,
  });

  /// EFA's line id, e.g. `ddb:90RE1: :H:j26` (with a space).
  final String lineId;
  final String tripCode;

  /// A stop of the run, e.g. where the user boards.
  final String stopId;

  /// The planned departure at [stopId], in UTC.
  final DateTime plannedDeparture;

  @override
  String toString() => 'RunKey($lineId, $tripCode, $stopId)';
}

/// One stop of a vehicle's run, with both arrival and departure: the
/// position of the vehicle lies between them.
class RunStop {
  const RunStop({
    required this.id,
    required this.name,
    this.parentId,
    this.arrivalPlanned,
    this.arrivalEstimated,
    this.departurePlanned,
    this.departureEstimated,
    this.platform,
    this.plannedPlatform,
    this.position,
  }) : assert(
         arrivalPlanned != null || departurePlanned != null,
         'A stop needs a time',
       );

  /// The stop down to the platform, e.g. `de:05911:5194:91:3`.
  final String id;

  /// The station, e.g. `de:05911:5194`.
  final String? parentId;

  /// Where the stop is, for the vehicle on the map.
  final GeoPoint? position;

  final String name;

  /// Null at the first stop of the run.
  final DateTime? arrivalPlanned;
  final DateTime? arrivalEstimated;

  /// Null at the last stop of the run.
  final DateTime? departurePlanned;
  final DateTime? departureEstimated;

  final String? platform;
  final String? plannedPlatform;

  /// The best known arrival; the departure at the first stop.
  DateTime get arrival =>
      arrivalEstimated ??
      arrivalPlanned ??
      departureEstimated ??
      departurePlanned!;

  /// The best known departure; the arrival at the last stop.
  DateTime get departure =>
      departureEstimated ??
      departurePlanned ??
      arrivalEstimated ??
      arrivalPlanned!;
}

/// Where the vehicle is at a given time. Calculated from the (live) times
/// of the run: EFA sends no GPS position.
sealed class RunPosition {
  const RunPosition();
}

/// Before the departure at the first stop.
final class RunNotStarted extends RunPosition {
  const RunNotStarted();
}

/// Standing at the stop with [index], between arrival and departure.
final class RunAtStop extends RunPosition {
  const RunAtStop(this.index);

  final int index;
}

/// Left the stop with [from], not yet at the next one.
final class RunBetween extends RunPosition {
  const RunBetween(this.from);

  final int from;
  int get to => from + 1;
}

/// Arrived at the last stop.
final class RunEnded extends RunPosition {
  const RunEnded();
}

/// A vehicle's whole run, from its first to its last stop.
class VehicleRun {
  VehicleRun(List<RunStop> stops, {this.isRealtime = false})
    : stops = List.unmodifiable(stops) {
    if (stops.length < 2) {
      throw ArgumentError.value(stops, 'stops', 'needs at least two stops');
    }
  }

  final List<RunStop> stops;

  /// EFA reports live data for this run (`realtimeStatus: MONITORED`);
  /// otherwise the times, and so the position, are the timetable's.
  final bool isRealtime;

  /// The index of the stop with [stopId], or failing that of the first stop
  /// at the same station [parentId]; null if the run does not stop there.
  int? indexOf(String stopId, {String? parentId}) {
    final exact = stops.indexWhere((stop) => stop.id == stopId);
    if (exact >= 0) return exact;
    if (parentId == null) return null;
    final station = stops.indexWhere((stop) => stop.parentId == parentId);
    return station >= 0 ? station : null;
  }

  RunPosition positionAt(DateTime now) {
    if (now.isBefore(stops.first.departure)) return const RunNotStarted();
    for (var i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final isLast = i == stops.length - 1;
      if (isLast) return const RunEnded();
      final leaves = i == 0 ? stop.departure : _leaves(stop);
      // Still at the stop until it leaves.
      if (now.isBefore(leaves) && !now.isBefore(stop.arrival)) {
        return RunAtStop(i);
      }
      if (now.isBefore(stops[i + 1].arrival)) return RunBetween(i);
    }
    return const RunEnded();
  }

  /// Where on the map the vehicle is at [now], estimated from the stop
  /// times: on a stop while it stands there, else on the straight line
  /// between the two stops, as far as the time between them has passed.
  /// Null before the start, after the end, or without the stops' points.
  GeoPoint? pointAt(DateTime now) {
    switch (positionAt(now)) {
      case RunAtStop(:final index):
        return stops[index].position;
      case RunBetween(:final from, :final to):
        final (a, b) = (stops[from], stops[to]);
        final (start, end) = (a.position, b.position);
        if (start == null || end == null) return start ?? end;
        final leaves = from == 0 ? a.departure : _leaves(a);
        final total = b.arrival.difference(leaves).inMilliseconds;
        final done = total <= 0
            ? 1.0
            : (now.difference(leaves).inMilliseconds / total).clamp(0.0, 1.0);
        return GeoPoint(
          start.latitude + (end.latitude - start.latitude) * done,
          start.longitude + (end.longitude - start.longitude) * done,
        );
      case RunNotStarted() || RunEnded():
        return null;
    }
  }

  /// When the vehicle leaves [stop]. Timetables count in minutes: "07:21
  /// arrival, 07:21 departure" means it stands there during that minute.
  static DateTime _leaves(RunStop stop) => stop.departure.isAfter(stop.arrival)
      ? stop.departure
      : stop.arrival.add(const Duration(minutes: 1));
}
