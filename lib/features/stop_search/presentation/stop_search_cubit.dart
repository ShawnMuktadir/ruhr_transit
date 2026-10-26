import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_state.dart';

/// Search-as-you-type for stops.
///
/// Requests start only after the user pauses typing for [debounce], and a
/// response is only shown if no newer query was entered in the meantime.
class StopSearchCubit extends Cubit<StopSearchState> {
  StopSearchCubit(
    this._repository, {
    this.debounce = const Duration(milliseconds: 300),
  }) : super(const StopSearchIdle());

  /// Shorter queries match too much to be useful and waste requests.
  static const minQueryLength = 2;

  final StopRepository _repository;
  final Duration debounce;

  Timer? _debounceTimer;
  String _query = '';

  /// Increased whenever the query changes. A response whose generation is
  /// no longer current is dropped, so a slow old response can never
  /// overwrite a newer one.
  int _generation = 0;

  void queryChanged(String input) {
    final query = input.trim();
    if (query == _query) return;
    _query = query;
    _debounceTimer?.cancel();
    _generation++;

    if (query.length < minQueryLength) {
      emit(const StopSearchIdle());
      return;
    }
    _debounceTimer = Timer(debounce, () => unawaited(_search(query)));
  }

  /// Repeats the current query right away, e.g. after a network error.
  Future<void> retry() async {
    if (_query.length < minQueryLength) return;
    _debounceTimer?.cancel();
    await _search(_query);
  }

  Future<void> _search(String query) async {
    final generation = ++_generation;
    emit(StopSearchLoading(query));

    final result = await _repository.searchStops(query);
    if (isClosed || generation != _generation) return;

    switch (result) {
      case Ok(value: final stops) when stops.isEmpty:
        emit(StopSearchEmpty(query));
      case Ok(value: final stops):
        emit(StopSearchLoaded(query, stops));
      // Only a superseded request is cancelled, and superseded results were
      // already dropped above. Kept as a guard.
      case Err(failure: CancelledFailure()):
        return;
      case Err(:final failure):
        emit(StopSearchFailed(query, failure));
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
