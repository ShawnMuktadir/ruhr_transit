import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// EFA code for "no location matches the input".
const _noMatchCode = -8020;

/// EFA product classes, verified against `transportation.product` in the
/// departure and trip fixtures. Classes seen on stops but not verified
/// (0, 7, 17) are intentionally missing.
const _modesByProductClass = {
  1: TransportMode.suburbanTrain, // S-Bahn
  2: TransportMode.subway, // U-Bahn (Stadtbahn)
  4: TransportMode.tram, // Straßenbahn
  5: TransportMode.bus, // Bus, Niederflurbus
  13: TransportMode.train, // RE, Regionalzug
  16: TransportMode.train, // ICE, Zug
};

/// Maps an `XML_STOPFINDER_REQUEST` response to stops, best match first.
///
/// Only `type: "stop"` locations are kept; POIs, streets and localities
/// have no departures. Throws [EfaServerException] when EFA reports an
/// error without results, and [FormatException] when the shape is wrong.
List<Stop> mapStopFinderResponse(Map<String, Object?> json) {
  final locations = switch (json['locations']) {
    null => const <Object?>[],
    final List<Object?> list => list,
    _ => throw const FormatException('"locations" is not a list'),
  };

  if (locations.isEmpty) {
    // Results win over messages: a successful response also carries an
    // error entry (-8011, empty text). Only an error without results is
    // a real error.
    final errors = readSystemMessages(
      json,
    ).where((m) => m.isError && m.code != _noMatchCode);
    if (errors.isNotEmpty) {
      throw EfaServerException(errors.first.code, errors.first.text);
    }
    return const [];
  }

  final ranked = <({Stop stop, bool isBest, int quality, int index})>[];
  for (final (index, location) in locations.indexed) {
    if (location is! Map<String, Object?>) {
      throw const FormatException('Location is not an object');
    }
    if (location['type'] != 'stop') continue;
    ranked.add((
      stop: _mapStop(location),
      isBest: location['isBest'] == true,
      quality: switch (location['matchQuality']) {
        final int quality => quality,
        _ => 0,
      },
      index: index,
    ));
  }

  // List.sort is not stable, so the original index breaks ties.
  ranked.sort((a, b) {
    if (a.isBest != b.isBest) return a.isBest ? -1 : 1;
    final byQuality = b.quality.compareTo(a.quality);
    return byQuality != 0 ? byQuality : a.index.compareTo(b.index);
  });
  return [for (final entry in ranked) entry.stop];
}

Stop _mapStop(Map<String, Object?> json) {
  final id = json['id'];
  final fullName = json['name'];
  if (id is! String || fullName is! String) {
    throw const FormatException('Stop without "id" or "name"');
  }

  // With coordOutputFormat=WGS84 EFA sends [latitude, longitude].
  final coord = json['coord'];
  if (coord case [final num latitude, final num longitude]) {
    return Stop(
      id: id,
      name: switch (json['disassembledName']) {
        final String name when name.isNotEmpty => name,
        _ => fullName,
      },
      fullName: fullName,
      locality: switch (json['parent']) {
        {'type': 'locality', 'name': final String name} => name,
        _ => null,
      },
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      modes: switch (json['productClasses']) {
        final List<Object?> classes => {
          for (final productClass in classes)
            ?_modesByProductClass[productClass],
        },
        _ => const {},
      },
    );
  }
  throw FormatException('Stop $id without valid "coord"');
}
