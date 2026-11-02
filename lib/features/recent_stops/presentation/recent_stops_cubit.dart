import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/features/recent_stops/domain/recent_stops_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// The last [limit] stops picked for From or To, newest first.
///
/// Like favourites: provided above the app, changes show at once and are
/// saved in the background.
class RecentStopsCubit extends Cubit<List<Stop>> {
  /// [initial] must be what [_repository] has stored: it is loaded before
  /// the app starts, so a pick right after starting cannot overwrite older
  /// history with a list that has only that pick.
  RecentStopsCubit(this._repository, {List<Stop> initial = const []})
    : super(List.unmodifiable(initial.take(limit)));

  static const limit = 10;

  final RecentStopsRepository _repository;

  /// Puts [stop] first; it appears only once.
  void add(Stop stop) =>
      _update([stop, ...state.where((recent) => recent != stop)]);

  /// Removes [stop] and returns its position for [restore], or -1.
  int remove(Stop stop) {
    final index = state.indexOf(stop);
    if (index >= 0) _update([...state]..removeAt(index));
    return index;
  }

  /// Undoes [remove].
  void restore(Stop stop, int index) {
    if (state.contains(stop)) return;
    _update([...state]..insert(index.clamp(0, state.length), stop));
  }

  /// Empties the history and returns it, for [restoreAll].
  List<Stop> clear() {
    final previous = state;
    _update(const []);
    return previous;
  }

  /// Undoes [clear].
  void restoreAll(List<Stop> stops) => _update(stops);

  void _update(List<Stop> stops) {
    final kept = List<Stop>.unmodifiable(stops.take(limit));
    emit(kept);
    unawaited(
      _repository.save(kept).catchError((Object e) {
        debugPrint('Could not save recent stops: $e');
      }),
    );
  }
}
