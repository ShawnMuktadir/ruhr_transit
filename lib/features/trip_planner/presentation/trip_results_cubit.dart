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

  /// EFA answers with about three journeys per request, whatever is asked
  /// for (live: 3 for calcNumberOfTrips 5, 8 and 10), and some may have
  /// left already. Later journeys are fetched until this many are shown.
  static const minimumJourneys = 5;

  /// At most this many extra requests to reach [minimumJourneys], so a
  /// quiet night does not keep asking VRR.
  static const _maxFillRequests = 3;

  /// Searches from scratch, showing a spinner. Used on opening and to
  /// retry.
  Future<void> load() async {
    emit(const TripResultsLoading());
    final result = await _repository.trips(query);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final journeys):
        emit(TripResultsLoaded(_withoutDeparted(journeys)));
        await _fillUp();
      // A newer request replaced this one and will set the state.
      case Err(failure: CancelledFailure()):
        return;
      case Err(:final failure):
        emit(TripResultsFailed(failure));
    }
  }

  /// Fetches later journeys until [minimumJourneys] are shown, EFA finds no
  /// new ones, or [_maxFillRequests] were made. The list shows meanwhile.
  ///
  /// Not outside NRW: each request can take minutes, so more trips are left
  /// to the "later trips" button.
  Future<void> _fillUp() async {
    if (query.isOutsideNrw) return;
    for (var i = 0; i < _maxFillRequests; i++) {
      final current = state;
      if (current is! TripResultsLoaded ||
          current.journeys.length >= minimumJourneys) {
        return;
      }
      // Nothing new (or a failure): asking again would not help.
      if (await _appendLater(reportFailure: false) == 0) return;
    }
  }

  /// Appends the journeys leaving after the last one shown ("later trips").
  Future<void> loadLater() => _appendLater(reportFailure: true);

  /// Returns how many journeys were added. A failure only shows when the
  /// user asked; while filling up automatically the list just stays.
  Future<int> _appendLater({required bool reportFailure}) async {
    final current = state;
    if (current is! TripResultsLoaded ||
        current.isLoadingLater ||
        current.journeys.isEmpty) {
      return 0;
    }
    emit(TripResultsLoaded(current.journeys, isLoadingLater: true));

    // A minute after the last departure; EFA would return it again
    // otherwise. The query time is local, like a picked time.
    final after = current.journeys.last.departure.time.toLocal().add(
      const Duration(minutes: 1),
    );
    final result = await _repository.trips(query.withTime(DepartAt(after)));
    if (isClosed) return 0;
    switch (result) {
      case Ok(value: final later):
        final known = {for (final j in current.journeys) _key(j)};
        // EFA may send journeys again, also ones that have left by now.
        final added = [
          for (final journey in _withoutDeparted(later))
            if (!known.contains(_key(journey))) journey,
        ];
        emit(TripResultsLoaded([...current.journeys, ...added]));
        return added.length;
      case Err(failure: CancelledFailure()):
        return 0;
      case Err(:final failure):
        emit(
          TripResultsLoaded(
            current.journeys,
            laterFailure: reportFailure ? failure : null,
          ),
        );
        return 0;
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
