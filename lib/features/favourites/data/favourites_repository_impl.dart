import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/features/favourites/data/stop_json.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavouritesRepositoryImpl implements FavouritesRepository {
  const FavouritesRepositoryImpl(this._preferences);

  /// Versioned, so a future format change can migrate from the old key
  /// instead of misreading it.
  static const storageKey = 'favourite_stops_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<Stop>> load() async {
    final stored = await _preferences.getString(storageKey);
    if (stored == null) return const [];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List<Object?>) {
        throw const FormatException('Favourites are not a list');
      }
      final stops = <Stop>[];
      for (final entry in decoded) {
        // One broken entry should not cost the user all other favourites.
        try {
          stops.add(stopFromJson(entry));
        } on FormatException catch (e) {
          debugPrint('Skipping unreadable favourite: $e');
        }
      }
      return stops;
    } on FormatException catch (e) {
      debugPrint('Ignoring unreadable favourites: $e');
      return const [];
    }
  }

  @override
  Future<void> save(List<Stop> stops) => _preferences.setString(
    storageKey,
    jsonEncode([for (final stop in stops) stopToJson(stop)]),
  );
}
