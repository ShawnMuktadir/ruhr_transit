import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_state.dart';

/// The departure board of one stop.
///
/// Loads only when asked to, on opening and on user refresh: the VRR terms
/// allow user-triggered queries, so there is no automatic polling.
class DeparturesCubit extends Cubit<DeparturesState> {
  DeparturesCubit(this._repository, this.stopId)
    : super(const DeparturesLoading());

  final DepartureRepository _repository;

  /// Global ID of the stop, e.g. `de:05911:5194`.
  final String stopId;

  /// Loads from scratch, showing a spinner. Used on opening and to retry
  /// after an error.
  Future<void> load() async {
    emit(const DeparturesLoading());
    await _fetch();
  }

  /// Reloads while keeping the current board visible. The returned future
  /// completes when the board is updated, which ends the pull-to-refresh
  /// indicator.
  Future<void> refresh() async {
    if (state is! DeparturesLoaded) return load();
    await _fetch();
  }

  Future<void> _fetch() async {
    final result = await _repository.departuresAt(stopId);
    if (isClosed) return;

    switch (result) {
      case Ok(value: final departures):
        emit(DeparturesLoaded(departures));
      // The repository cancels a request when a newer one starts; that one
      // will update the state.
      case Err(failure: CancelledFailure()):
        return;
      case Err(:final failure):
        emit(switch (state) {
          DeparturesLoaded(:final departures) => DeparturesLoaded(
            departures,
            refreshFailure: failure,
          ),
          _ => DeparturesFailed(failure),
        });
    }
  }
}
