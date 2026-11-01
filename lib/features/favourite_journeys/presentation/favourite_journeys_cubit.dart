import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journeys_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Sealed, so the list must show loading and errors too.
sealed class FavouriteJourneysState {
  const FavouriteJourneysState();
}

final class FavouriteJourneysLoading extends FavouriteJourneysState {
  const FavouriteJourneysLoading();
}

final class FavouriteJourneysLoaded extends FavouriteJourneysState {
  const FavouriteJourneysLoaded(this.journeys);

  /// Oldest first.
  final List<FavouriteJourney> journeys;
}

/// The database could not be read.
final class FavouriteJourneysFailed extends FavouriteJourneysState {
  const FavouriteJourneysFailed();
}

/// The saved journeys, kept up to date from the database.
///
/// Provided once above the app, so the bookmark on the planner, the results
/// and the trip details agree with the list in the Favourites tab.
class FavouriteJourneysCubit extends Cubit<FavouriteJourneysState> {
  FavouriteJourneysCubit(
    this._repository, {
    DateTime Function() now = DateTime.now,
  }) : _now = now,
       super(const FavouriteJourneysLoading()) {
    _watch();
  }

  final FavouriteJourneysRepository _repository;
  final DateTime Function() _now;
  StreamSubscription<List<FavouriteJourney>>? _subscription;

  void _watch() {
    _subscription = _repository.watchAll().listen(
      (journeys) => emit(FavouriteJourneysLoaded(List.unmodifiable(journeys))),
      onError: (Object e) {
        debugPrint('Could not read saved journeys: $e');
        emit(const FavouriteJourneysFailed());
      },
    );
  }

  void retry() {
    // The old subscription delivers nothing more once cancel is called;
    // waiting for the returned future would only delay the new read.
    unawaited(_subscription?.cancel());
    emit(const FavouriteJourneysLoading());
    _watch();
  }

  /// The saved journey from [from] to [to], or null.
  FavouriteJourney? find(Stop from, Stop to) => switch (state) {
    FavouriteJourneysLoaded(:final journeys) =>
      journeys.where((journey) => journey.connects(from, to)).firstOrNull,
    _ => null,
  };

  /// Saves the journey from [from] to [to], or removes it if it is saved.
  Future<void> toggle(Stop from, Stop to) {
    if (find(from, to) case final saved?) return remove(saved);
    return _write(
      _repository.save(FavouriteJourney(from: from, to: to, savedAt: _now())),
    );
  }

  Future<void> remove(FavouriteJourney journey) =>
      _write(_repository.remove(journey.from, journey.to));

  /// Undoes [remove]; the journey returns to its old place in the list.
  Future<void> restore(FavouriteJourney journey) =>
      _write(_repository.save(journey));

  Future<void> setLabel(FavouriteJourney journey, String? label) =>
      _write(_repository.save(journey.withLabel(label)));

  /// The list updates through the repository's stream; a failed write
  /// leaves it as it was, which is then what the user sees.
  Future<void> _write(Future<void> write) => write.catchError((Object e) {
    debugPrint('Could not change saved journeys: $e');
  });

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
