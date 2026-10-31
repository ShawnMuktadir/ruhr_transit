import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/stop_search/data/stop_mapper.dart';

import '../../../helpers/fixtures.dart';

Map<String, Object?> _stop(
  String id, {
  bool isBest = false,
  int matchQuality = 0,
}) => {
  'id': id,
  'name': 'Town, $id',
  'coord': [51.0, 7.0],
  'type': 'stop',
  'isBest': isBest,
  'matchQuality': matchQuality,
};

void main() {
  group('mapStopFinderResponse with recorded responses', () {
    test('keeps only stops, not POIs, best match first', () {
      final stops = mapStopFinderResponse(
        readEfaFixtureJson('stopfinder_bochum_hbf'),
      );

      // The fixture has 3 stops and 7 POIs.
      expect(stops.map((s) => s.id), [
        'de:05911:5194',
        'de:05911:5691',
        'de:05911:5494',
      ]);
    });

    test('maps the fields of Bochum Hbf', () {
      final stop = mapStopFinderResponse(
        readEfaFixtureJson('stopfinder_bochum_hbf'),
      ).first;

      expect(stop.name, 'Hbf');
      expect(stop.fullName, 'Bochum, Hbf');
      expect(stop.locality, 'Bochum');
      expect(stop.latitude, 51.479466);
      expect(stop.longitude, 7.223335);
      // productClasses [0, 1, 2, 4, 5, 7, 13, 17]: 0, 7 and 17 are not
      // verified and are left out.
      expect(stop.modes, {
        TransportMode.suburbanTrain,
        TransportMode.subway,
        TransportMode.tram,
        TransportMode.bus,
        TransportMode.train,
      });
    });

    test('treats the -8011 message on a successful response as success', () {
      final json = readEfaFixtureJson('stopfinder_bochum_hbf');
      expect(readSystemMessages(json).single.code, -8011);

      expect(mapStopFinderResponse(json), isNotEmpty);
    });

    test('returns an empty list for "no match" (-8020)', () {
      expect(
        mapStopFinderResponse(readEfaFixtureJson('stopfinder_no_match')),
        isEmpty,
      );
    });
  });

  group('mapStopFinderResponse with edge cases', () {
    test('throws EfaServerException for another error without results', () {
      final json = {
        'systemMessages': [
          {'type': 'error', 'module': 'BROKER', 'code': -8010, 'text': 'x'},
        ],
        'locations': <Object?>[],
      };

      expect(
        () => mapStopFinderResponse(json),
        throwsA(
          isA<EfaServerException>()
              .having((e) => e.code, 'code', -8010)
              .having((e) => e.message, 'message', 'x'),
        ),
      );
    });

    test('ignores warnings when there are no results', () {
      final json = {
        'systemMessages': [
          {'type': 'warning', 'code': 1},
        ],
      };

      expect(mapStopFinderResponse(json), isEmpty);
    });

    test('sorts isBest first, then by matchQuality, keeping ties stable', () {
      final json = {
        'locations': [
          _stop('a', matchQuality: 500),
          _stop('b', matchQuality: 900),
          _stop('c', isBest: true, matchQuality: 100),
          _stop('d', matchQuality: 500),
        ],
      };

      expect(mapStopFinderResponse(json).map((s) => s.id), [
        'c',
        'b',
        'a',
        'd',
      ]);
    });

    test('falls back to the full name without disassembledName', () {
      final stop = mapStopFinderResponse({
        'locations': [_stop('a')],
      }).single;

      expect(stop.name, 'Town, a');
      expect(stop.locality, isNull);
      expect(stop.modes, isEmpty);
    });

    test('throws FormatException for malformed shapes', () {
      expect(
        () => mapStopFinderResponse({'locations': 'nope'}),
        throwsFormatException,
      );
      expect(
        () => mapStopFinderResponse({
          'locations': [
            {
              'type': 'stop',
              'name': 'No id',
              'coord': <Object?>[51, 7],
            },
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => mapStopFinderResponse({
          'locations': [
            {'type': 'stop', 'id': 'x', 'name': 'No coord'},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  group('decodeEfaJson', () {
    test('throws FormatException for invalid bodies', () {
      expect(() => decodeEfaJson(null), throwsFormatException);
      expect(() => decodeEfaJson(''), throwsFormatException);
      expect(() => decodeEfaJson('<html>'), throwsFormatException);
      expect(() => decodeEfaJson('[1, 2]'), throwsFormatException);
    });
  });
}
