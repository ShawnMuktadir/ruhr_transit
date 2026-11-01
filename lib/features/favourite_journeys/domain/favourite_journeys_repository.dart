import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

abstract interface class FavouriteJourneysRepository {
  /// All saved journeys, oldest first, and again after every change.
  Stream<List<FavouriteJourney>> watchAll();

  /// Adds [journey], or replaces the one between the same stops.
  Future<void> save(FavouriteJourney journey);

  Future<void> remove(Stop from, Stop to);
}
