import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/network/efa_transport.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

/// Maps an `XML_STOPSEQCOORD_REQUEST` response: `leg.stopSequence` lists
/// every stop of the vehicle's run with planned and live times.
///
/// Throws [FormatException] when there is no usable run (fewer than two
/// stops with a name and a time).
VehicleRun mapRunResponse(Map<String, Object?> json) {
  final leg = switch (json['leg']) {
    final Map<String, Object?> leg => leg,
    _ => throw const FormatException('Response without "leg"'),
  };
  final sequence = switch (leg['stopSequence']) {
    final List<Object?> stops => stops,
    _ => throw const FormatException('Run without "stopSequence"'),
  };
  final stops = [
    for (final stop in sequence)
      if (stop is Map<String, Object?>) ?_mapStop(stop),
  ];
  if (stops.length < 2) {
    throw const FormatException('Run with fewer than two stops');
  }
  return VehicleRun(
    stops,
    isRealtime: switch (leg['realtimeStatus']) {
      final List<Object?> status => status.contains('MONITORED'),
      _ => false,
    },
  );
}

/// Null for a stop without id, name or any planned time: one odd stop
/// should not cost the whole run.
RunStop? _mapStop(Map<String, Object?> json) {
  final id = readNonEmptyString(json['id']);
  final name = readEfaStopName(json['name']);
  final arrivalPlanned = readEfaTime(json['arrivalTimePlanned']);
  final departurePlanned = readEfaTime(json['departureTimePlanned']);
  if (id == null ||
      name == null ||
      (arrivalPlanned == null && departurePlanned == null)) {
    return null;
  }
  final properties = switch (json['properties']) {
    final Map<String, Object?> properties => properties,
    _ => const <String, Object?>{},
  };
  return RunStop(
    id: id,
    name: name,
    parentId: switch (json['parent']) {
      {'id': final String parent} when parent.isNotEmpty => parent,
      _ => null,
    },
    arrivalPlanned: arrivalPlanned,
    arrivalEstimated: readEfaTime(json['arrivalTimeEstimated']),
    departurePlanned: departurePlanned,
    departureEstimated: readEfaTime(json['departureTimeEstimated']),
    platform: readNonEmptyString(properties['platformName']),
    plannedPlatform: readNonEmptyString(properties['plannedPlatformName']),
    position: readGeoPoint(json['coord']),
  );
}
