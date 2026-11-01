import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/nearby_stops/data/nearby_stops_mapper.dart';
import 'package:ruhr_transit/features/stop_search/data/stop_mapper.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('mapCoordResponse with recorded responses', () {
    test('maps the stops around Bochum Hbf, closest first', () {
      final nearby = mapCoordResponse(
        readEfaFixtureJson('coord_nearby_bochum_hbf'),
      );

      expect(
        [for (final n in nearby) n.distanceMeters],
        [0, 167, 387, 529, 533],
      );
      final hbf = nearby.first.stop;
      expect(hbf.id, 'de:05911:5194');
      expect(hbf.name, 'Hbf');
      expect(hbf.locality, 'Bochum');
      expect(hbf.latitude, 51.479466);
      expect(hbf.longitude, 7.223335);
      expect(hbf.modes, {
        TransportMode.train,
        TransportMode.suburbanTrain,
        TransportMode.subway,
        TransportMode.tram,
        TransportMode.bus,
      });
    });

    test('names stops the way the stop finder does', () {
      final nearby = mapCoordResponse(
        readEfaFixtureJson('coord_nearby_bochum_hbf'),
      );
      final searched = mapStopFinderResponse(
        readEfaFixtureJson('stopfinder_bochum_hbf'),
      ).first;

      expect(nearby.first.stop.fullName, searched.fullName);
      expect(nearby.first.stop.name, searched.name);
      // Also when the name repeats the town; checked against a live stop
      // finder response, which has "Bochum, Bochum Hbf/Boulevard".
      expect(nearby[1].stop.fullName, 'Bochum, Bochum Hbf/Boulevard');
      expect(nearby[1].stop.name, 'Bochum Hbf/Boulevard');
    });

    test('no stop nearby is an empty list', () {
      expect(
        mapCoordResponse(readEfaFixtureJson('coord_nearby_none')),
        isEmpty,
      );
    });
  });

  test('sorts by distance whatever order EFA sends', () {
    Map<String, Object?> stop(String id, num distance) => {
      'id': id,
      'name': id,
      'type': 'stop',
      'coord': [51.0, 7.0],
      'properties': {'distance': distance},
    };

    final nearby = mapCoordResponse({
      'locations': [
        stop('far', 900),
        {'id': 'poi', 'type': 'poi', 'name': 'Café'},
        stop('near', 120.4),
      ],
    });

    expect([for (final n in nearby) n.stop.id], ['near', 'far']);
    expect(nearby.first.distanceMeters, 120);
    // Without a town, the full name is just the name.
    expect(nearby.first.stop.fullName, 'near');
  });

  test('an error without results becomes EfaServerException', () {
    expect(
      () => mapCoordResponse({
        'systemMessages': [
          {'type': 'error', 'code': -8010, 'text': ''},
        ],
      }),
      throwsA(isA<EfaServerException>()),
    );
  });

  test('a stop without distance is a FormatException', () {
    expect(
      () => mapCoordResponse({
        'locations': [
          {
            'id': 'x',
            'name': 'X',
            'type': 'stop',
            'coord': [51.0, 7.0],
          },
        ],
      }),
      throwsFormatException,
    );
  });
}
