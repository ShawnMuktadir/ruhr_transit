import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// The user's favourite stops, in the order they were added.
///
/// Provided once above the app, so the star on a departure board and the
/// list on the start screen always agree. Changes show immediately and are
/// saved in the background; a local write is fast and practically never
/// fails, so the UI does not wait for it.
class FavouritesCubit extends Cubit<List<Stop>> {
  /// [initial] must be what [_repository] has stored. It is loaded before
  /// the app starts: every change saves the whole list, so a change made
  /// before an asynchronous load finished would overwrite the saved stops.
  FavouritesCubit(this._repository, {List<Stop> initial = const []})
    : super(List.unmodifiable(initial));

  final FavouritesRepository _repository;

  bool isFavourite(Stop stop) => state.contains(stop);

  void toggle(Stop stop) {
    if (isFavourite(stop)) {
      remove(stop);
    } else {
      _update([...state, stop]);
    }
  }

  /// Removes [stop] and returns its position for [restore], or -1 if it was
  /// not a favourite.
  int remove(Stop stop) {
    final index = state.indexOf(stop);
    if (index >= 0) _update([...state]..removeAt(index));
    return index;
  }

  /// Undoes [remove]: puts [stop] back at [index], or at the end if the
  /// list got shorter in the meantime.
  void restore(Stop stop, int index) {
    if (isFavourite(stop)) return;
    _update([...state]..insert(index.clamp(0, state.length), stop));
  }

  void _update(List<Stop> stops) {
    emit(List.unmodifiable(stops));
    unawaited(
      _repository.save(stops).catchError((Object e) {
        debugPrint('Could not save favourites: $e');
      }),
    );
  }
}
