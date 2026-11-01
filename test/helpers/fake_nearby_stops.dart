import 'dart:async';

import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';

import 'fake_stop_repository.dart';

/// Hand-written fake: answers with [result], or waits for [pending] if set.
class FakeLocationSource implements LocationSource {
  LocationResult result = bochumHbfLocation;
  Completer<LocationResult>? pending;
  int calls = 0;
  int appSettingsOpened = 0;
  int locationSettingsOpened = 0;

  @override
  Future<LocationResult> currentLocation() {
    calls++;
    return pending?.future ?? Future.value(result);
  }

  @override
  Future<void> openAppSettings() async => appSettingsOpened++;

  @override
  Future<void> openLocationSettings() async => locationSettingsOpened++;
}

/// Records the points asked for and answers with [reply].
class FakeNearbyStopsRepository implements NearbyStopsRepository {
  final List<(double, double)> points = [];
  Result<List<NearbyStop>> reply = const Ok(nearbyStops);

  @override
  Future<Result<List<NearbyStop>>> stopsNear({
    required double latitude,
    required double longitude,
  }) async {
    points.add((latitude, longitude));
    return reply;
  }
}

const bochumHbfLocation = Located(latitude: 51.4794, longitude: 7.2233);

const nearbyStops = [
  NearbyStop(bochumHbf, distanceMeters: 40),
  NearbyStop(dortmundHbf, distanceMeters: 350),
];
