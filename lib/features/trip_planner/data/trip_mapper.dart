import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/core/network/efa_text.dart';
import 'package:ruhr_transit/core/network/efa_transport.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

/// EFA product classes of walks (`"name": "footpath"`): 99 between two
/// stops, 100 to or from an address or place (both seen live).
const _footpathClasses = {99, 100};

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

  if (transportation case {
    'product': {'class': final int productClass},
  } when _footpathClasses.contains(productClass)) {
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
      steps: _mapWalkSteps(json['pathDescriptions']),
      stationPaths: _mapStationPaths(json['footPathInfo']),
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
    runKey: _mapRunKey(transportation, json['origin'], origin.plannedTime),
    originId: _mapStopRef(json['origin']),
    destinationId: _mapStopRef(json['destination']),
    isRealtime: switch (json['realtimeStatus']) {
      final List<Object?> status => status.contains('MONITORED'),
      _ => json['isRealtimeControlled'] == true,
    },
    transferSteps: _mapWalkSteps(json['pathDescriptions']),
    transferPaths: _mapStationPaths(json['footPathInfo']),
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
  final name = readEfaStopName(json['name']);
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

/// Null without line id, trip code or stop id: the run cannot be
/// requested then.
RunKey? _mapRunKey(
  Map<String, Object?> transportation,
  Object? origin,
  DateTime plannedDeparture,
) {
  final lineId = readNonEmptyString(transportation['id']);
  final tripCode = switch (transportation['properties']) {
    {'tripCode': final int code} => '$code',
    {'tripCode': final String code} when code.isNotEmpty => code,
    _ => null,
  };
  final stopId = switch (origin) {
    {'id': final String id} when id.isNotEmpty => id,
    _ => null,
  };
  if (lineId == null || tripCode == null || stopId == null) return null;
  return RunKey(
    lineId: lineId,
    tripCode: tripCode,
    stopId: stopId,
    plannedDeparture: plannedDeparture,
  );
}

List<WalkStep> _mapWalkSteps(Object? json) => switch (json) {
  final List<Object?> steps => [
    for (final step in steps)
      if (step is Map<String, Object?>) _mapWalkStep(step),
  ],
  _ => const [],
};

WalkStep _mapWalkStep(Map<String, Object?> json) {
  final name = readNonEmptyString(json['name'])?.trim();
  return WalkStep(
    turn: switch ((json['manoeuvre'], json['turnDirection'])) {
      ('ENTER_TRAIN' || 'ENTER', _) => WalkTurn.board,
      ('LEAVE' || 'LEAVE_TRAIN', _) => WalkTurn.alight,
      (_, 'STRAIGHT') => WalkTurn.straight,
      (_, 'SLIGHT_LEFT') => WalkTurn.slightLeft,
      (_, 'LEFT') => WalkTurn.left,
      (_, 'SHARP_LEFT') => WalkTurn.sharpLeft,
      (_, 'SLIGHT_RIGHT') => WalkTurn.slightRight,
      (_, 'RIGHT') => WalkTurn.right,
      (_, 'SHARP_RIGHT') => WalkTurn.sharpRight,
      (_, 'U_TURN' || 'UTURN') => WalkTurn.uTurn,
      _ => WalkTurn.unknown,
    },
    // "Fußweg" says nothing the walking icon does not.
    name: name == null || name == 'Fußweg' ? null : name,
    distanceMeters: switch (json['distance']) {
      final int meters => meters,
      _ => 0,
    },
    duration: Duration(
      seconds: switch (json['duration']) {
        final int seconds => seconds,
        _ => 0,
      },
    ),
  );
}

/// `footPathInfo` is a list of positions (before or after the walk), each
/// with its elements: lifts, escalators, stairs between levels.
List<StationPath> _mapStationPaths(Object? json) => switch (json) {
  final List<Object?> infos => [
    for (final info in infos)
      if (info case {'footPathElem': final List<Object?> elements})
        for (final element in elements)
          if (element is Map<String, Object?>) ?_mapStationPath(element),
  ],
  _ => const [],
};

/// Null for `LEVEL`, a walk on one level, which is no lift or stairs.
StationPath? _mapStationPath(Map<String, Object?> json) {
  final kind = switch (json['type']) {
    'ELEVATOR' => StationPathKind.elevator,
    'ESCALATOR' => StationPathKind.escalator,
    'STAIRS' => StationPathKind.stairs,
    'LEVEL' => null,
    _ => StationPathKind.other,
  };
  final from = switch (json['levelFrom']) {
    final int level => level,
    _ => null,
  };
  final to = switch (json['levelTo']) {
    final int level => level,
    _ => null,
  };
  if (kind == null || (from != null && from == to)) return null;
  return StationPath(kind: kind, levelFrom: from, levelTo: to);
}

StopRef? _mapStopRef(Object? json) => switch (json) {
  {'id': final String id} when id.isNotEmpty => StopRef(
    id,
    parentId: switch (json) {
      {'parent': {'id': final String parent}} when parent.isNotEmpty => parent,
      _ => null,
    },
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
      readEfaStopName(json['name']) ??
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
