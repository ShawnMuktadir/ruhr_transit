import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/core/network/efa_transport.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';

/// EFA product class of a walk between stops (`"name": "footpath"`).
const _footpathClass = 99;

/// EFA code for "origin too close to destination": nothing to ride, so no
/// journeys rather than an error.
const _tooCloseCode = -4007;

/// Maps an `XML_TRIP_REQUEST2` response to journeys, earliest departure
/// first.
///
/// A successful response carries a warning (-10015, "itp"), so messages only
/// matter without journeys. Throws [EfaServerException] for an error without
/// journeys, and [FormatException] when the shape is wrong.
List<Journey> mapTripResponse(Map<String, Object?> json) {
  final journeys = switch (json['journeys']) {
    null => const <Object?>[],
    final List<Object?> list => list,
    _ => throw const FormatException('"journeys" is not a list'),
  };

  if (journeys.isEmpty) {
    final errors = readSystemMessages(json).where((m) => m.isError).toList();
    if (errors.isEmpty || errors.any((m) => m.code == _tooCloseCode)) {
      return const [];
    }
    throw EfaServerException(errors.first.code, errors.first.text);
  }

  final mapped = [
    for (final journey in journeys)
      switch (journey) {
        {'legs': final List<Object?> legs} when legs.isNotEmpty => Journey([
          for (final leg in legs) _mapLeg(leg),
        ]),
        _ => throw const FormatException('Journey without legs'),
      },
  ];
  // List.sort is not stable, so ties keep EFA's order through the index.
  final indexed = mapped.indexed.toList()
    ..sort((a, b) {
      final byTime = a.$2.departure.time.compareTo(b.$2.departure.time);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  return [for (final (_, journey) in indexed) journey];
}

Leg _mapLeg(Object? json) {
  if (json is! Map<String, Object?>) {
    throw const FormatException('Leg is not an object');
  }
  final transportation = switch (json['transportation']) {
    final Map<String, Object?> transportation => transportation,
    _ => throw const FormatException('Leg without "transportation"'),
  };
  final origin = _mapStop(json['origin'], 'departure');
  final destination = _mapStop(json['destination'], 'arrival');

  if (transportation case {'product': {'class': _footpathClass}}) {
    return WalkLeg(
      duration: switch (json['duration']) {
        final int seconds => Duration(seconds: seconds),
        // Without its own duration, the walk takes the time between stops.
        _ => destination.time.difference(origin.time),
      },
      distanceMeters: switch (json['distance']) {
        final int meters => meters,
        _ => null,
      },
      origin: origin,
      destination: destination,
    );
  }

  return TransitLeg(
    line: readEfaLine(transportation),
    mode: readEfaMode(transportation),
    direction: switch (transportation['destination']) {
      {'name': final String name} when name.isNotEmpty => name,
      // Rare, but the leg's own end is a sensible direction to show.
      _ => destination.name,
    },
    origin: origin,
    destination: destination,
    notes: readEfaRealtimeNotes(json['hints']),
  );
}

/// [timeKind] is `departure` for a leg's origin and `arrival` for its
/// destination.
TripStop _mapStop(Object? json, String timeKind) {
  if (json is! Map<String, Object?>) {
    throw const FormatException('Leg without origin or destination');
  }
  final name = switch (json['name']) {
    final String name when name.isNotEmpty => name,
    _ => throw const FormatException('Leg stop without name'),
  };
  final plannedTime = readEfaTime(json['${timeKind}TimePlanned']);
  if (plannedTime == null) {
    throw FormatException('$name without "${timeKind}TimePlanned"');
  }
  final properties = switch (json['properties']) {
    final Map<String, Object?> properties => properties,
    _ => const <String, Object?>{},
  };
  return TripStop(
    name: name,
    plannedTime: plannedTime,
    estimatedTime: readEfaTime(json['${timeKind}TimeEstimated']),
    platform: readNonEmptyString(properties['platformName']),
    plannedPlatform: readNonEmptyString(properties['plannedPlatformName']),
  );
}
