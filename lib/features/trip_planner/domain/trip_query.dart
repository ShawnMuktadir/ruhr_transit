import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// What the user asked for: from where, to where, and when.
class TripQuery {
  const TripQuery({required this.from, required this.to, required this.time});

  final Stop from;
  final Stop to;
  final TripTime time;

  /// Neither end is in NRW, so VRR's service may take minutes or not answer.
  bool get isOutsideNrw => !from.isInNrw && !to.isInNrw;

  TripQuery withTime(TripTime time) =>
      TripQuery(from: from, to: to, time: time);
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
