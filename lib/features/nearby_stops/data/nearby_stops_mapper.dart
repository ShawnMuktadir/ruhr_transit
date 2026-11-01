import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/stop_search/data/stop_mapper.dart';

/// Maps an `XML_COORD_REQUEST` response to stops, closest first.
///
/// No stop nearby is `"locations": []` without any message. Throws
/// [EfaServerException] when EFA reports an error without results, and
/// [FormatException] when the shape is wrong.
List<NearbyStop> mapCoordResponse(Map<String, Object?> json) {
  final locations = switch (json['locations']) {
    null => const <Object?>[],
    final List<Object?> list => list,
    _ => throw const FormatException('"locations" is not a list'),
  };

  if (locations.isEmpty) {
    final errors = readSystemMessages(json).where((m) => m.isError);
    if (errors.isNotEmpty) {
      throw EfaServerException(errors.first.code, errors.first.text);
    }
    return const [];
  }

  final stops = <NearbyStop>[];
  for (final location in locations) {
    if (location is! Map<String, Object?>) {
      throw const FormatException('Location is not an object');
    }
    if (location['type'] != 'stop') continue;
    final distance = switch (location['properties']) {
      {'distance': final num distance} => distance.round(),
      _ => throw FormatException('Stop ${location['id']} without distance'),
    };
    stops.add(
      NearbyStop(
        mapEfaStop(location, nameIncludesLocality: false),
        distanceMeters: distance,
      ),
    );
  }
  // Closest first, whatever order EFA used. List.sort is not stable, but
  // equal distances have no meaningful order anyway.
  return stops..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
}
