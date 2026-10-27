import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/departures/data/departure_mapper.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';

import '../../../helpers/fixtures.dart';

Map<String, Object?> _event({Map<String, Object?>? platforms, Object? hints}) =>
    {
      'departureTimePlanned': '2026-10-25T17:13:00Z',
      'location': {'properties': ?platforms},
      'transportation': {
        'disassembledName': 'RE16',
        'product': {'class': 13},
        'destination': {'name': 'Essen Hauptbahnhof'},
      },
      'hints': ?hints,
    };

Departure _single(Map<String, Object?> event) => mapDepartureMonitorResponse({
  'stopEvents': [event],
}).single;

void main() {
  group('mapDepartureMonitorResponse with the recorded Bochum Hbf board', () {
    late List<Departure> departures;

    setUpAll(() {
      departures = mapDepartureMonitorResponse(
        readEfaFixtureJson('dm_bochum_hbf'),
      );
    });

    test('keeps all departures in EFA order', () {
      expect(departures, hasLength(20));
      final times = departures.map((d) => d.plannedTime).toList();
      expect(times, [...times]..sort());
    });

    test('maps a delayed train with realtime data', () {
      final re16 = departures.first;

      expect(re16.line, 'RE16');
      expect(re16.mode, TransportMode.train);
      expect(re16.destination, 'Essen Hauptbahnhof');
      expect(re16.plannedTime, DateTime.utc(2026, 10, 25, 17, 13));
      expect(re16.plannedTime.isUtc, isTrue);
      expect(re16.estimatedTime, DateTime.utc(2026, 10, 25, 17, 25));
      expect(re16.delay, const Duration(minutes: 12));
      expect(re16.platform, '3');
      expect(re16.plannedPlatform, '3');
      expect(re16.platformChanged, isFalse);
      expect(re16.isCancelled, isFalse);
      expect(re16.notes, ['Vorfahrt eines anderen Zuges']);
    });

    test('marks cancelled departures, which have no estimate', () {
      final cancelled = departures.where((d) => d.isCancelled).toList();

      expect(cancelled.map((d) => d.line), ['RE11', 'RE11']);
      expect(cancelled.map((d) => d.estimatedTime), [null, null]);
    });

    test('a missing estimate means no realtime, not "on time"', () {
      final bus336 = departures.singleWhere((d) => d.line == '336');

      expect(bus336.estimatedTime, isNull);
      expect(bus336.delay, isNull);
    });

    test('falls back to the line number for long-distance trains', () {
      // ICE/IC entries have no disassembledName.
      expect(departures[6].line, '546');
      expect(departures[6].mode, TransportMode.train);
    });

    test('maps trams, subways and buses with their platforms', () {
      expect(departures[2].mode, TransportMode.tram);
      expect(departures[2].platform, 'Gleis 5 (U)');
      expect(
        departures.where((d) => d.line == 'U35').map((d) => d.mode),
        everyElement(TransportMode.subway),
      );
      expect(departures.last.mode, TransportMode.bus);
      expect(departures.last.platform, '01');
    });

    test('keeps only realtime incident hints as notes', () {
      // RB40 also has the timetable hint "Linie RB40: WLAN verfügbar".
      expect(departures[1].notes, ['Witterungsbedingte Beeinträchtigungen']);
      expect(departures[4].notes, isEmpty);
    });
  });

  group('mapDepartureMonitorResponse edge cases', () {
    test('detects a platform change', () {
      final departure = _single(
        _event(platforms: {'platformName': '4', 'plannedPlatformName': '3'}),
      );

      expect(departure.platform, '4');
      expect(departure.plannedPlatform, '3');
      expect(departure.platformChanged, isTrue);
    });

    test('works without platform, realtime and hints', () {
      final departure = _single(_event());

      expect(departure.platform, isNull);
      expect(departure.platformChanged, isFalse);
      expect(departure.estimatedTime, isNull);
      expect(departure.notes, isEmpty);
    });

    test('drops duplicate and empty notes', () {
      const hint = {'type': 'RTIncidentCall', 'content': 'Signalstörung'};
      final departure = _single(
        _event(
          hints: [
            hint,
            hint,
            {'type': 'RTIncidentCall', 'content': ''},
          ],
        ),
      );

      expect(departure.notes, ['Signalstörung']);
    });

    test('an unknown product class gives no mode', () {
      final event = _event();
      (event['transportation']! as Map<String, Object?>)['product'] = {
        'class': 99,
      };

      expect(_single(event).mode, isNull);
    });

    test('no events and no messages is an empty board', () {
      expect(mapDepartureMonitorResponse({'stopEvents': []}), isEmpty);
      expect(mapDepartureMonitorResponse({}), isEmpty);
    });

    test('no events with an error message throws EfaServerException', () {
      expect(
        () => mapDepartureMonitorResponse({
          'systemMessages': [
            {'type': 'error', 'code': -8010, 'text': 'unknown stop'},
          ],
        }),
        throwsA(
          isA<EfaServerException>()
              .having((e) => e.code, 'code', -8010)
              .having((e) => e.message, 'message', 'unknown stop'),
        ),
      );
    });

    test('error messages are ignored when there are departures', () {
      final departures = mapDepartureMonitorResponse({
        'stopEvents': [_event()],
        'systemMessages': [
          {'type': 'error', 'code': -8011, 'text': ''},
        ],
      });

      expect(departures, hasLength(1));
    });

    test('throws FormatException for malformed responses', () {
      final withoutTime = _event()..remove('departureTimePlanned');
      final withoutDestination = _event();
      (withoutDestination['transportation']! as Map<String, Object?>).remove(
        'destination',
      );

      for (final json in <Map<String, Object?>>[
        {'stopEvents': 'nope'},
        {
          'stopEvents': ['nope'],
        },
        {
          'stopEvents': [withoutTime],
        },
        {
          'stopEvents': [withoutDestination],
        },
        {
          'stopEvents': [
            {...withoutTime, 'departureTimePlanned': 'yesterday'},
          ],
        },
      ]) {
        expect(
          () => mapDepartureMonitorResponse(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });
  });
}
