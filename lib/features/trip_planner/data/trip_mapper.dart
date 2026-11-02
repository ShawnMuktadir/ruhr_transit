import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/core/network/efa_text.dart';
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
  final notices = _mapNotices(json['infos']);

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
      notices: notices,
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
    intermediateStops: _mapIntermediateStops(json['stopSequence']),
    notices: notices,
  );
}

/// `stopSequence` lists every stop of the leg, origin and destination
/// included. Stops in between have both an arrival and a departure time;
/// the departure is what a passenger waits for.
List<TripStop> _mapIntermediateStops(Object? json) {
  if (json is! List<Object?> || json.length < 3) return const [];
  return [
    for (final stop in json.sublist(1, json.length - 1))
      if (stop is Map<String, Object?>) ?_mapIntermediateStop(stop),
  ];
}

/// Null for a stop without a name or time: one odd stop should not cost
/// the whole trip.
TripStop? _mapIntermediateStop(Map<String, Object?> json) {
  final name = _stopName(json['name']);
  final departure = readEfaTime(json['departureTimePlanned']);
  final plannedTime = departure ?? readEfaTime(json['arrivalTimePlanned']);
  if (name == null || plannedTime == null) return null;
  final properties = switch (json['properties']) {
    final Map<String, Object?> properties => properties,
    _ => const <String, Object?>{},
  };
  return TripStop(
    name: name,
    plannedTime: plannedTime,
    estimatedTime: readEfaTime(
      json[departure != null
          ? 'departureTimeEstimated'
          : 'arrivalTimeEstimated'],
    ),
    platform: readNonEmptyString(properties['platformName']),
    plannedPlatform: readNonEmptyString(properties['plannedPlatformName']),
  );
}

/// EFA sometimes has two spaces in a name ("Bochum  Gesundheitscampus").
String? _stopName(Object? json) => switch (json) {
  final String name when name.trim().isNotEmpty => name.trim().replaceAll(
    RegExp(r'\s+'),
    ' ',
  ),
  _ => null,
};

List<TripNotice> _mapNotices(Object? json) => switch (json) {
  final List<Object?> infos => [
    for (final info in infos)
      if (info is Map<String, Object?>) ?_mapNotice(info),
  ],
  _ => const [],
};

/// Null for a notice without id or anything to show.
TripNotice? _mapNotice(Map<String, Object?> json) {
  final id = readNonEmptyString(json['id']);
  final link = switch (json['infoLinks']) {
    [final Map<String, Object?> first, ...] => first,
    _ => const <String, Object?>{},
  };
  final text = switch (link['content']) {
    final String content => efaPlainText(content),
    _ => '',
  };
  final title =
      readNonEmptyString(link['title']) ?? readNonEmptyString(link['subtitle']);
  if (id == null || (title == null && text.isEmpty)) return null;
  final summary = switch (link['urlText']) {
    final String urlText => efaPlainText(urlText),
    _ => '',
  };
  return TripNotice(
    id: id,
    kind: switch (json['type']) {
      'infrastructure' => TripNoticeKind.facilities,
      'stopInfo' => TripNoticeKind.stop,
      'lineInfo' => TripNoticeKind.line,
      'tripMessage' => TripNoticeKind.trip,
      _ => TripNoticeKind.other,
    },
    // Without a title, the text's first line stands in.
    title: (title ?? text.split('\n').first).trim(),
    summary: summary.isEmpty || summary == title ? null : summary,
    text: text,
    priority: switch (json['priority']) {
      'low' || 'veryLow' => TripNoticePriority.low,
      'high' || 'veryHigh' => TripNoticePriority.high,
      _ => TripNoticePriority.normal,
    },
  );
}

/// [timeKind] is `departure` for a leg's origin and `arrival` for its
/// destination.
TripStop _mapStop(Object? json, String timeKind) {
  if (json is! Map<String, Object?>) {
    throw const FormatException('Leg without origin or destination');
  }
  final name =
      _stopName(json['name']) ??
      (throw const FormatException('Leg stop without name'));
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
