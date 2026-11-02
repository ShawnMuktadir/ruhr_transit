import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/features/favourites/data/stop_json.dart';
import 'package:ruhr_transit/features/recent_stops/domain/recent_stops_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored like favourite stops: a JSON list in shared preferences, in the
/// same stop format.
class RecentStopsRepositoryImpl implements RecentStopsRepository {
  const RecentStopsRepositoryImpl(this._preferences);

  static const storageKey = 'recent_stops_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<Stop>> load() async {
    final stored = await _preferences.getString(storageKey);
    if (stored == null) return const [];
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! List<Object?>) {
        throw const FormatException('Recent stops are not a list');
      }
      final stops = <Stop>[];
      for (final entry in decoded) {
        // A broken entry costs only itself; it is history, not a favourite.
        try {
          stops.add(stopFromJson(entry));
        } on FormatException catch (e) {
          debugPrint('Skipping unreadable recent stop: $e');
        }
      }
      return stops;
    } on FormatException catch (e) {
      debugPrint('Ignoring unreadable recent stops: $e');
      return const [];
    }
  }

  @override
  Future<void> save(List<Stop> stops) => stops.isEmpty
      ? _preferences.remove(storageKey)
      : _preferences.setString(
          storageKey,
          jsonEncode([for (final stop in stops) stopToJson(stop)]),
        );
}
