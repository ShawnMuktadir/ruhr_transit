import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/features/departures/data/departure_json.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The last fetched board of the most recently loaded stops, so a board can
/// still be shown when the server cannot be reached.
///
/// All boards live in one JSON map under one key. Changing it means
/// read-modify-write, so writes are queued: two boards saving at the same
/// time must not drop each other's entry. That only works with one instance,
/// so this is registered as a singleton.
class DepartureCache {
  DepartureCache(this._preferences, {this.maxStops = 10});

  /// Versioned, so a future format change can migrate from the old key
  /// instead of misreading it.
  static const storageKey = 'departure_boards_v1';

  final SharedPreferencesAsync _preferences;

  /// How many stops are kept; the boards fetched longest ago are dropped
  /// first. Bounds the storage at a few KB per stop.
  final int maxStops;

  /// The write that runs last; the next operation waits for it.
  Future<void> _queue = Future.value();

  /// The saved board of [stopId], or null if there is none or it cannot be
  /// read.
  Future<DepartureBoard?> read(String stopId) async {
    // Waits for pending writes, so a board saved just before is found.
    await _queue;
    final entry = (await _readAll())[stopId];
    if (entry == null) return null;
    try {
      return boardFromJson(entry);
    } on FormatException catch (e) {
      debugPrint('Ignoring unreadable departure board: $e');
      return null;
    }
  }

  /// Saves [board] as the last board of [stopId], replacing the previous
  /// one. Errors reach the caller, but do not block later writes.
  Future<void> write(String stopId, DepartureBoard board) {
    final write = _queue.then((_) => _write(stopId, board));
    _queue = write.then((_) {}, onError: (Object _) {});
    return write;
  }

  Future<void> _write(String stopId, DepartureBoard board) async {
    final boards = await _readAll()
      ..remove(stopId);
    // Map literals keep insertion order, so the newest board goes last and
    // the oldest are at the front.
    boards[stopId] = boardToJson(board);
    final overflow = boards.length - maxStops;
    if (overflow > 0) {
      boards.keys.take(overflow).toList().forEach(boards.remove);
    }
    await _preferences.setString(storageKey, jsonEncode(boards));
  }

  /// All saved boards as raw JSON, oldest first. Unreadable data is treated
  /// as empty; the next write replaces it.
  Future<Map<String, Object?>> _readAll() async {
    final stored = await _preferences.getString(storageKey);
    if (stored == null) return {};
    try {
      final decoded = jsonDecode(stored);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Departure boards are not a map');
      }
      return decoded;
    } on FormatException catch (e) {
      debugPrint('Ignoring unreadable departure boards: $e');
      return {};
    }
  }
}
