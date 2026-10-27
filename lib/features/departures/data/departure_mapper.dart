import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/core/network/efa_product.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';

/// Maps an `XML_DM_REQUEST` response (`depType=stopEvents`) to departures,
/// in the order EFA sends them (by planned time).
///
/// Throws [EfaServerException] when EFA reports an error without
/// departures, and [FormatException] when the shape is wrong.
List<Departure> mapDepartureMonitorResponse(Map<String, Object?> json) {
  final events = switch (json['stopEvents']) {
    null => const <Object?>[],
    final List<Object?> list => list,
    _ => throw const FormatException('"stopEvents" is not a list'),
  };

  if (events.isEmpty) {
    // Same rule as the stop finder: messages only matter without results.
    final errors = readSystemMessages(json).where((m) => m.isError);
    if (errors.isNotEmpty) {
      throw EfaServerException(errors.first.code, errors.first.text);
    }
    return const [];
  }

  return [
    for (final event in events)
      if (event is Map<String, Object?>)
        _mapDeparture(event)
      else
        throw const FormatException('Stop event is not an object'),
  ];
}

Departure _mapDeparture(Map<String, Object?> json) {
  final transportation = json['transportation'];
  if (transportation is! Map<String, Object?>) {
    throw const FormatException('Stop event without "transportation"');
  }
  final plannedTime = _readTime(json['departureTimePlanned']);
  if (plannedTime == null) {
    throw const FormatException('Stop event without "departureTimePlanned"');
  }

  final platforms = switch (json['location']) {
    {'properties': final Map<String, Object?> properties} => properties,
    _ => const <String, Object?>{},
  };

  return Departure(
    line: _readLine(transportation),
    mode: switch (transportation['product']) {
      {'class': final int productClass} => transportModeForProductClass(
        productClass,
      ),
      _ => null,
    },
    destination: switch (transportation['destination']) {
      {'name': final String name} => name,
      _ => throw const FormatException('Stop event without destination'),
    },
    plannedTime: plannedTime,
    estimatedTime: _readTime(json['departureTimeEstimated']),
    platform: _readNonEmpty(platforms['platformName']),
    plannedPlatform: _readNonEmpty(platforms['plannedPlatformName']),
    // `realtimeStatus` contains TRIP_CANCELLED only sometimes; this flag is
    // the reliable one.
    isCancelled: json['isCancelled'] == true,
    notes: _readNotes(json['hints']),
  );
}

/// Most lines have `disassembledName` (`RE16`); long-distance trains don't,
/// so `number` (`945`) and then `name` are the fallbacks.
String _readLine(Map<String, Object?> transportation) {
  for (final key in ['disassembledName', 'number', 'name']) {
    if (_readNonEmpty(transportation[key]) case final line?) return line;
  }
  throw const FormatException('Stop event without line name');
}

/// EFA sends UTC timestamps like `2026-10-25T17:13:00Z`.
DateTime? _readTime(Object? value) =>
    value is String ? DateTime.parse(value) : null;

String? _readNonEmpty(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Only realtime incident hints (`RTIncidentCall`). `Timetable` hints are
/// amenities like "WLAN verfügbar" that would bury the important ones.
List<String> _readNotes(Object? hints) {
  if (hints is! List<Object?>) return const [];
  return {
    for (final hint in hints)
      if (hint case {
        'type': 'RTIncidentCall',
        'content': final String content,
      } when content.isNotEmpty)
        content,
  }.toList();
}
