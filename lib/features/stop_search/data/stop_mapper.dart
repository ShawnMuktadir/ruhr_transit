import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/core/network/efa_product.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// EFA code for "no location matches the input".
const _noMatchCode = -8020;

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
      stop: mapEfaStop(location, nameIncludesLocality: true),
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

/// Maps one EFA location of `type: "stop"`.
///
/// The stop finder sends `name` with the town ("Bochum, Hbf") and the short
/// name in `disassembledName`; the coordinate request sends only the short
/// name. [nameIncludesLocality] says which one [json] is, so a stop gets the
/// same names whichever way it was found: favourites and the widget store
/// them.
Stop mapEfaStop(
  Map<String, Object?> json, {
  required bool nameIncludesLocality,
}) {
  final id = json['id'];
  final rawName = json['name'];
  if (id is! String || rawName is! String) {
    throw const FormatException('Stop without "id" or "name"');
  }
  final locality = switch (json['parent']) {
    {'type': 'locality', 'name': final String name} => name,
    _ => null,
  };

  final String name;
  final String fullName;
  if (nameIncludesLocality) {
    fullName = rawName;
    name = switch (json['disassembledName']) {
      final String short when short.isNotEmpty => short,
      _ => rawName,
    };
  } else {
    name = rawName;
    // The stop finder's format, also when the name repeats the town:
    // "Bochum, Bochum Hbf/Boulevard".
    fullName = locality == null ? rawName : '$locality, $rawName';
  }

  // With coordOutputFormat=WGS84 EFA sends [latitude, longitude].
  final coord = json['coord'];
  if (coord case [final num latitude, final num longitude]) {
    return Stop(
      id: id,
      name: name,
      fullName: fullName,
      locality: locality,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      modes: switch (json['productClasses']) {
        final List<Object?> classes => {
          for (final productClass in classes)
            ?transportModeForProductClass(productClass),
        },
        _ => const {},
      },
    );
  }
  throw FormatException('Stop $id without valid "coord"');
}
