import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A list kept as JSON under one key in shared preferences: favourites,
/// recent stops, reminders.
///
/// One unreadable entry costs only itself, and an unreadable list reads as
/// empty, so a broken save never stops the app.
class JsonListStore<T> {
  const JsonListStore(
    this._preferences, {
    required this.key,
    required this.fromJson,
    required this.toJson,
  });

  final SharedPreferencesAsync _preferences;

  /// Versioned, e.g. `favourite_stops_v1`, so a future format change can
  /// migrate from the old key instead of misreading it.
  final String key;

  /// Reads one entry; null or a [FormatException] when it cannot.
  final T? Function(Object? json) fromJson;
  final Object? Function(T value) toJson;

  Future<List<T>> load() async {
    final stored = await _preferences.getString(key);
    if (stored == null) return const [];
    final Object? decoded;
    try {
      decoded = jsonDecode(stored);
    } on FormatException catch (e) {
      debugPrint('Ignoring unreadable $key: $e');
      return const [];
    }
    if (decoded is! List<Object?>) {
      debugPrint('Ignoring $key: not a list');
      return const [];
    }
    final values = <T>[];
    for (final entry in decoded) {
      try {
        if (fromJson(entry) case final value?) {
          values.add(value);
        } else {
          debugPrint('Skipping an unreadable entry of $key');
        }
      } on FormatException catch (e) {
        debugPrint('Skipping an unreadable entry of $key: $e');
      }
    }
    return values;
  }

  /// An empty list removes the key.
  Future<void> save(List<T> values) => values.isEmpty
      ? _preferences.remove(key)
      : _preferences.setString(
          key,
          jsonEncode([for (final value in values) toJson(value)]),
        );
}
