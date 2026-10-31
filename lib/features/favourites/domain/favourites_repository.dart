import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Stops the user saved, stored on the device.
///
/// Stores the whole list at once: it is short, and the order (the order
/// stops were added in) is part of the data.
abstract interface class FavouritesRepository {
  /// The saved stops, in their saved order. Unreadable data gives an empty
  /// list rather than an error: losing favourites is better than an app
  /// that cannot start.
  Future<List<Stop>> load();

  Future<void> save(List<Stop> stops);
}
