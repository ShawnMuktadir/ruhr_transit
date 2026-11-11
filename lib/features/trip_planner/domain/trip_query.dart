import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_means.dart';

/// What the user asked for: from where, to where, when, and without which
/// means of transport.
class TripQuery {
  const TripQuery({
    required this.from,
    required this.to,
    required this.time,
    this.excluded = const {},
  });

  final Stop from;
  final Stop to;
  final TripTime time;

  /// Turned off by the user; VRR plans without them.
  final Set<TripMeans> excluded;

  /// Neither end is in NRW, so VRR's service may take minutes or not answer.
  bool get isOutsideNrw => !from.isInNrw && !to.isInNrw;

  TripQuery withTime(TripTime time) =>
      TripQuery(from: from, to: to, time: time, excluded: excluded);

  TripQuery withExcluded(Set<TripMeans> excluded) =>
      TripQuery(from: from, to: to, time: time, excluded: excluded);
}

/// Sealed, so the request and the form must handle every kind of time.
sealed class TripTime {
  const TripTime();
}

/// Leave as soon as possible.
final class LeaveNow extends TripTime {
  const LeaveNow();
}

/// Leave at or after [time] (local time, as picked).
final class DepartAt extends TripTime {
  const DepartAt(this.time);

  final DateTime time;
}

/// Arrive at or before [time] (local time, as picked).
final class ArriveBy extends TripTime {
  const ArriveBy(this.time);

  final DateTime time;
}
