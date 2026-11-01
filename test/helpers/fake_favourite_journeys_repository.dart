import 'dart:async';

import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journeys_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// In-memory saved journeys that notify watchers like the database does.
class FakeFavouriteJourneysRepository implements FavouriteJourneysRepository {
  FakeFavouriteJourneysRepository([List<FavouriteJourney> initial = const []])
    : saved = [...initial];

  List<FavouriteJourney> saved;

  /// When set, watching fails with this error.
  Object? readError;

  final _changes = StreamController<void>.broadcast();

  /// The current list on listen, then after every change. Not async*: a
  /// generator waiting in `await for` cannot be cancelled until its next
  /// event, which would make closing the cubit hang.
  @override
  Stream<List<FavouriteJourney>> watchAll() {
    // Only ever cancelled by its listener, like a drift query stream.
    // ignore: close_sinks
    late final StreamController<List<FavouriteJourney>> controller;
    StreamSubscription<void>? changes;
    controller = StreamController(
      onListen: () {
        if (readError case final error?) {
          controller.addError(error);
          return;
        }
        controller.add(_sorted());
        changes = _changes.stream.listen((_) => controller.add(_sorted()));
      },
      // Not closing the controller here: its close() waits for this
      // cancel to finish, so awaiting it would deadlock.
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }

  List<FavouriteJourney> _sorted() =>
      [...saved]..sort((a, b) => a.savedAt.compareTo(b.savedAt));

  @override
  Future<void> save(FavouriteJourney journey) async {
    saved = [
      for (final j in saved)
        if (!j.connects(journey.from, journey.to)) j,
      journey,
    ];
    _changes.add(null);
  }

  @override
  Future<void> remove(Stop from, Stop to) async {
    saved = [
      for (final j in saved)
        if (!j.connects(from, to)) j,
    ];
    _changes.add(null);
  }
}
