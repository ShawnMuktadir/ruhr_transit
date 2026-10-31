import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';

/// Storage format of a saved board. This is the app's own format, not
/// EFA's: the cache must stay readable if the EFA mapping changes.
Map<String, Object?> boardToJson(DepartureBoard board) => {
  'fetchedAt': board.fetchedAt.toUtc().toIso8601String(),
  'departures': [for (final d in board.departures) departureToJson(d)],
};

/// Reads [boardToJson] output. Throws [FormatException] if the board or any
/// of its departures is broken: a board with gaps would look complete.
DepartureBoard boardFromJson(Object? json) {
  if (json case {
    'fetchedAt': final String fetchedAt,
    'departures': final List<Object?> departures,
  }) {
    return DepartureBoard([
      for (final d in departures) departureFromJson(d),
    ], fetchedAt: _parseUtc(fetchedAt));
  }
  throw FormatException('Not a saved departure board: $json');
}

/// Times are stored in UTC like EFA sends them; modes by enum name, so
/// reordering [TransportMode] does not change saved data.
Map<String, Object?> departureToJson(Departure departure) => {
  'line': departure.line,
  'mode': departure.mode?.name,
  'destination': departure.destination,
  'plannedTime': departure.plannedTime.toUtc().toIso8601String(),
  'estimatedTime': departure.estimatedTime?.toUtc().toIso8601String(),
  'platform': departure.platform,
  'plannedPlatform': departure.plannedPlatform,
  'isCancelled': departure.isCancelled,
  'notes': departure.notes,
};

/// Reads [departureToJson] output. Throws [FormatException] if a required
/// field is missing; an unknown mode (e.g. from a newer app version) is read
/// as null, as the EFA mapper does.
Departure departureFromJson(Object? json) {
  if (json case {
    'line': final String line,
    'destination': final String destination,
    'plannedTime': final String plannedTime,
  }) {
    return Departure(
      line: line,
      mode: TransportMode.values.asNameMap()[json['mode']],
      destination: destination,
      plannedTime: _parseUtc(plannedTime),
      estimatedTime: switch (json['estimatedTime']) {
        final String time => _parseUtc(time),
        _ => null,
      },
      platform: _optionalString(json['platform']),
      plannedPlatform: _optionalString(json['plannedPlatform']),
      isCancelled: json['isCancelled'] == true,
      notes: switch (json['notes']) {
        final List<Object?> notes => List.unmodifiable(
          notes.whereType<String>(),
        ),
        _ => const [],
      },
    );
  }
  throw FormatException('Not a saved departure: $json');
}

String? _optionalString(Object? value) => value is String ? value : null;

DateTime _parseUtc(String value) => DateTime.parse(value).toUtc();
