import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';

/// What the trip form shows. Plain values; nothing is loaded here.
class TripFormState {
  const TripFormState({
    this.from,
    this.to,
    this.time = const LeaveNow(),
    this.here,
  });

  final Stop? from;
  final Stop? to;
  final TripTime time;

  /// The address found for the user's location; the field holding it says
  /// "current location", also after swapping.
  final Stop? here;

  bool get isSameStop => from != null && from == to;

  /// The query to search with, or null while the form is incomplete.
  TripQuery? get query => switch ((from, to)) {
    (final from?, final to?) when from != to => TripQuery(
      from: from,
      to: to,
      time: time,
    ),
    _ => null,
  };
}

/// The trip form: start, destination and time.
class TripFormCubit extends Cubit<TripFormState> {
  TripFormCubit({Stop? from, DateTime Function() now = DateTime.now})
    : _now = now,
      super(TripFormState(from: from));

  final DateTime Function() _now;

  void setFrom(Stop stop) => emit(
    TripFormState(from: stop, to: state.to, time: state.time, here: state.here),
  );

  void setTo(Stop stop) => emit(
    TripFormState(
      from: state.from,
      to: stop,
      time: state.time,
      here: state.here,
    ),
  );

  /// Starts from where the user is.
  void setFromHere(Stop here) => emit(
    TripFormState(from: here, to: state.to, time: state.time, here: here),
  );

  void swap() => emit(
    TripFormState(
      from: state.to,
      to: state.from,
      time: state.time,
      here: state.here,
    ),
  );

  void leaveNow() => _setTime(const LeaveNow());

  /// Keeps the chosen time when switching between depart and arrive, and
  /// starts from now when switching away from "now".
  void departAt([DateTime? time]) =>
      _setTime(DepartAt(time ?? _chosenTime ?? _now()));

  void arriveBy([DateTime? time]) =>
      _setTime(ArriveBy(time ?? _chosenTime ?? _now()));

  DateTime? get _chosenTime => switch (state.time) {
    DepartAt(:final time) || ArriveBy(:final time) => time,
    LeaveNow() => null,
  };

  void _setTime(TripTime time) => emit(
    TripFormState(from: state.from, to: state.to, time: time, here: state.here),
  );
}
