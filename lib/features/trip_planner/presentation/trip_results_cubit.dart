import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_state.dart';

/// Journeys for one query. Loads on request only, like the departure board.
class TripResultsCubit extends Cubit<TripResultsState> {
  TripResultsCubit(
    this._repository,
    this.query, {
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       super(const TripResultsLoading());

  final TripRepository _repository;
  final TripQuery query;
  final DateTime Function() _now;

  /// How long ago a journey may have left and still be shown, as phone
  /// clocks are often slightly off.
  static const _clockTolerance = Duration(minutes: 1);

  /// Searches from scratch, showing a spinner. Used on opening and to
  /// retry.
  Future<void> load() async {
    emit(const TripResultsLoading());
    final result = await _repository.trips(query);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final journeys):
        emit(TripResultsLoaded(_withoutDeparted(journeys)));
      // A newer request replaced this one and will set the state.
      case Err(failure: CancelledFailure()):
        return;
      case Err(:final failure):
        emit(TripResultsFailed(failure));
    }
  }

  /// Appends the journeys leaving after the last one shown.
  Future<void> loadLater() async {
    final current = state;
    if (current is! TripResultsLoaded ||
        current.isLoadingLater ||
        current.journeys.isEmpty) {
      return;
    }
    emit(TripResultsLoaded(current.journeys, isLoadingLater: true));

    // A minute after the last departure; EFA would return it again
    // otherwise. The query time is local, like a picked time.
    final after = current.journeys.last.departure.time.toLocal().add(
      const Duration(minutes: 1),
    );
    final result = await _repository.trips(query.withTime(DepartAt(after)));
    if (isClosed) return;
    switch (result) {
      case Ok(value: final later):
        final known = {for (final j in current.journeys) _key(j)};
        emit(
          TripResultsLoaded([
            ...current.journeys,
            for (final journey in later)
              if (!known.contains(_key(journey))) journey,
          ]),
        );
      case Err(failure: CancelledFailure()):
        return;
      case Err(:final failure):
        emit(TripResultsLoaded(current.journeys, laterFailure: failure));
    }
  }

  /// For "leave now", EFA also returns journeys that left minutes ago (seen
  /// live: one 14 minutes earlier). Nobody can take them any more.
  List<Journey> _withoutDeparted(List<Journey> journeys) {
    if (query.time is! LeaveNow) return journeys;
    final earliest = _now().subtract(_clockTolerance);
    return [
      for (final journey in journeys)
        if (!journey.departure.time.isBefore(earliest)) journey,
    ];
  }

  /// Journeys have no ID; the same lines at the same planned times are the
  /// same journey.
  static String _key(Journey journey) => [
    for (final leg in journey.legs)
      switch (leg) {
        TransitLeg(:final line) => '$line@${leg.origin.plannedTime}',
        WalkLeg() => 'walk@${leg.origin.plannedTime}',
      },
  ].join('|');
}
