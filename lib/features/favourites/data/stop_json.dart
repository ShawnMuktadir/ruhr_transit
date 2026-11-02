import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Storage format of a saved stop. Modes are stored by enum name, so
/// reordering [TransportMode] does not change saved data.
Map<String, Object?> stopToJson(Stop stop) => {
  'id': stop.id,
  'name': stop.name,
  'fullName': stop.fullName,
  'locality': stop.locality,
  'latitude': stop.latitude,
  'longitude': stop.longitude,
  'modes': [for (final mode in stop.modes) mode.name],
  'kind': stop.kind.name,
};

/// Reads [stopToJson] output. Throws [FormatException] if a required field
/// is missing; unknown modes (e.g. from a newer app version) are skipped.
Stop stopFromJson(Object? json) {
  if (json case {
    'id': final String id,
    'name': final String name,
    'fullName': final String fullName,
    'latitude': final num latitude,
    'longitude': final num longitude,
  }) {
    return Stop(
      id: id,
      name: name,
      fullName: fullName,
      locality: switch (json['locality']) {
        final String locality => locality,
        _ => null,
      },
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      modes: switch (json['modes']) {
        final List<Object?> names => {
          for (final mode in TransportMode.values)
            if (names.contains(mode.name)) mode,
        },
        _ => const {},
      },
      // Stored before addresses existed: a stop.
      kind:
          LocationKind.values
              .where((kind) => kind.name == json['kind'])
              .firstOrNull ??
          LocationKind.stop,
    );
  }
  throw FormatException('Not a saved stop: $json');
}
