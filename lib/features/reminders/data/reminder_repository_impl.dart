import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/favourites/data/stop_json.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored as JSON. [SharedPreferencesAsync] has no cache, so the app sees
/// what the alarm wrote while it ran in the background.
class ReminderRepositoryImpl implements ReminderRepository {
  const ReminderRepositoryImpl(this._preferences);

  static const storageKey = 'reminders_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<List<Reminder>> load() async {
    final raw = await _preferences.getString(storageKey);
    if (raw == null) return const [];
    try {
      final entries = jsonDecode(raw) as List<Object?>;
      return [for (final entry in entries) ?_read(entry)];
    } on FormatException catch (e) {
      debugPrint('Unreadable reminders: $e');
      return const [];
    } on TypeError catch (e) {
      debugPrint('Unreadable reminders: $e');
      return const [];
    }
  }

  @override
  Future<void> save(List<Reminder> reminders) => _preferences.setString(
    storageKey,
    jsonEncode([for (final reminder in reminders) _write(reminder)]),
  );

  static Map<String, Object?> _write(Reminder r) => {
    'id': r.id,
    'key': r.key,
    'line': r.line,
    'mode': r.mode?.name,
    'stopName': r.stopName,
    'platform': r.platform,
    'plannedDeparture': r.plannedDeparture.toUtc().toIso8601String(),
    'departure': r.departure.toUtc().toIso8601String(),
    'walkBeforeSeconds': r.walkBefore.inSeconds,
    'leadSeconds': r.lead.inSeconds,
    'languageCode': r.languageCode,
    'use24HourFormat': r.use24HourFormat,
    'originStopId': r.originStopId,
    'originParentId': r.originParentId,
    if (r.boardStop case final stop?) 'boardStop': stopToJson(stop),
    if (r.tripFrom case final stop?) 'tripFrom': stopToJson(stop),
    if (r.tripTo case final stop?) 'tripTo': stopToJson(stop),
    if (r.runKey case final key?)
      'run': {
        'lineId': key.lineId,
        'tripCode': key.tripCode,
        'stopId': key.stopId,
        'plannedDeparture': key.plannedDeparture.toUtc().toIso8601String(),
      },
  };

  /// Null for an entry that cannot be read; the others still count.
  static Reminder? _read(Object? json) {
    if (json case {
      'id': final int id,
      'key': final String key,
      'line': final String line,
      'stopName': final String stopName,
      'plannedDeparture': final String plannedDeparture,
      'departure': final String departure,
      'walkBeforeSeconds': final int walkBeforeSeconds,
      'leadSeconds': final int leadSeconds,
      'languageCode': final String languageCode,
      'use24HourFormat': final bool use24HourFormat,
    } when json is Map<String, Object?>) {
      final planned = DateTime.tryParse(plannedDeparture);
      final best = DateTime.tryParse(departure);
      if (planned == null || best == null) return null;
      return Reminder(
        id: id,
        key: key,
        line: line,
        mode: TransportMode.values
            .where((mode) => mode.name == json['mode'])
            .firstOrNull,
        stopName: stopName,
        platform: json['platform'] as String?,
        plannedDeparture: planned,
        departure: best,
        walkBefore: Duration(seconds: walkBeforeSeconds),
        lead: Duration(seconds: leadSeconds),
        languageCode: languageCode,
        use24HourFormat: use24HourFormat,
        originStopId: json['originStopId'] as String?,
        originParentId: json['originParentId'] as String?,
        runKey: _readRunKey(json['run']),
        boardStop: _readStop(json['boardStop']),
        tripFrom: _readStop(json['tripFrom']),
        tripTo: _readStop(json['tripTo']),
      );
    }
    return null;
  }

  /// Reminders saved before this field, or with a broken one, have none.
  static Stop? _readStop(Object? json) {
    if (json == null) return null;
    try {
      return stopFromJson(json);
    } on FormatException {
      return null;
    }
  }

  static RunKey? _readRunKey(Object? json) {
    if (json case {
      'lineId': final String lineId,
      'tripCode': final String tripCode,
      'stopId': final String stopId,
      'plannedDeparture': final String plannedDeparture,
    }) {
      if (DateTime.tryParse(plannedDeparture) case final planned?) {
        return RunKey(
          lineId: lineId,
          tripCode: tripCode,
          stopId: stopId,
          plannedDeparture: planned,
        );
      }
    }
    return null;
  }
}
