import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/core/network/efa_transport.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';

/// Maps an `XML_DM_REQUEST` response (`depType=stopEvents`) to departures,
/// in the order EFA sends them. That is not strictly by planned time: live
/// responses put a heavily delayed departure first.
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
  final plannedTime = readEfaTime(json['departureTimePlanned']);
  if (plannedTime == null) {
    throw const FormatException('Stop event without "departureTimePlanned"');
  }

  final platforms = switch (json['location']) {
    {'properties': final Map<String, Object?> properties} => properties,
    _ => const <String, Object?>{},
  };

  return Departure(
    line: readEfaLine(transportation),
    mode: readEfaMode(transportation),
    destination: switch (transportation['destination']) {
      {'name': final String name} => name,
      _ => throw const FormatException('Stop event without destination'),
    },
    plannedTime: plannedTime,
    estimatedTime: readEfaTime(json['departureTimeEstimated']),
    platform: readNonEmptyString(platforms['platformName']),
    plannedPlatform: readNonEmptyString(platforms['plannedPlatformName']),
    // `realtimeStatus` contains TRIP_CANCELLED only sometimes; this flag is
    // the reliable one.
    isCancelled: json['isCancelled'] == true,
    notes: readEfaRealtimeNotes(json['hints']),
  );
}
