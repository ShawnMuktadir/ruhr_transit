import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';

import '../../../helpers/fixtures.dart';

void main() {
  group('mapTripResponse with recorded responses', () {
    test('maps direct trips with realtime, earliest first', () {
      final journeys = mapTripResponse(
        readEfaFixtureJson('trip_bochum_dortmund'),
      );

      expect(journeys, hasLength(3));
      final s1 = journeys.first.legs.single as TransitLeg;
      expect(s1.line, 'S1');
      expect(s1.mode, TransportMode.suburbanTrain);
      expect(s1.direction, 'Dortmund Hbf');
      expect(s1.origin.name, 'Bochum Hbf');
      expect(s1.origin.plannedTime, DateTime.utc(2026, 10, 25, 17, 14));
      expect(s1.origin.estimatedTime, DateTime.utc(2026, 10, 25, 17, 17));
      expect(s1.origin.delay, const Duration(minutes: 3));
      expect(s1.origin.platform, '8');
      expect(s1.destination.name, 'Dortmund Hbf');
      expect(s1.destination.time, DateTime.utc(2026, 10, 25, 17, 39));
      // Only realtime incidents; this leg has amenity hints only.
      expect(s1.notes, isEmpty);

      expect(journeys.first.transfers, 0);
      expect(journeys.first.duration, const Duration(minutes: 22));
      // Long-distance trains have no disassembledName.
      expect((journeys.last.legs.single as TransitLeg).line, '945');
      expect(journeys.last.legs.single.origin.platform, '5');
    });

    test('maps a walk between two rides', () {
      final journeys = mapTripResponse(readEfaFixtureJson('trip_with_walk'));

      expect(journeys, hasLength(4));
      final [u35, walk, bus] = journeys.first.legs;
      expect(u35, isA<TransitLeg>().having((l) => l.line, 'line', 'U35'));
      expect(u35.destination.platform, 'Gleis 3 (U)');
      expect(
        walk,
        isA<WalkLeg>()
            .having((l) => l.duration, 'duration', const Duration(minutes: 4))
            .having((l) => l.distanceMeters, 'distanceMeters', 183),
      );
      expect(walk.origin.name, 'Bochum Hbf');
      expect(walk.destination.name, 'Bochum Hbf/Boulevard');
      expect(
        bus,
        isA<TransitLeg>()
            .having((l) => l.line, 'line', '368')
            .having((l) => l.mode, 'mode', TransportMode.bus)
            .having((l) => l.direction, 'direction', 'Bochum Ruhr Park/UCI'),
      );
      // A walk is not a ride: U35 to bus is one transfer.
      expect(journeys.first.transfers, 1);
      expect(journeys.first.duration, const Duration(minutes: 16));
      expect(journeys[1].legs.single, isA<TransitLeg>());
    });
  });

  Map<String, Object?> stop(String name, String kind, String planned) => {
    'name': name,
    '${kind}TimePlanned': planned,
  };

  Map<String, Object?> ride(String line, String dep, String arr) => {
    'origin': stop('A', 'departure', dep),
    'destination': stop('B', 'arrival', arr),
    'transportation': {
      'disassembledName': line,
      'product': {'class': 5},
      'destination': {'name': 'Somewhere'},
    },
  };

  test('sorts journeys by expected departure', () {
    final journeys = mapTripResponse({
      'journeys': [
        {
          'legs': [
            ride('late', '2026-11-02T08:30:00Z', '2026-11-02T08:40:00Z'),
          ],
        },
        {
          'legs': [
            ride('early', '2026-11-02T08:10:00Z', '2026-11-02T08:20:00Z'),
          ],
        },
      ],
    });

    expect(
      [for (final j in journeys) (j.legs.single as TransitLeg).line],
      ['early', 'late'],
    );
  });

  test('a walk without its own duration takes the time between stops', () {
    final journeys = mapTripResponse({
      'journeys': [
        {
          'legs': [
            {
              'origin': stop('A', 'departure', '2026-11-02T08:00:00Z'),
              'destination': stop('B', 'arrival', '2026-11-02T08:06:00Z'),
              'transportation': {
                'product': {'class': 99, 'name': 'footpath'},
              },
            },
          ],
        },
      ],
    });

    final walk = journeys.single.legs.single as WalkLeg;
    expect(walk.duration, const Duration(minutes: 6));
    expect(walk.distanceMeters, isNull);
  });

  test('origin too close to destination means no journeys', () {
    expect(
      mapTripResponse({
        'systemMessages': [
          {'type': 'error', 'code': -4007, 'text': 'origin too close'},
        ],
      }),
      isEmpty,
    );
  });

  test('other errors without journeys become EfaServerException', () {
    expect(
      () => mapTripResponse({
        'systemMessages': [
          {'type': 'error', 'code': -4001, 'text': 'invalid date'},
        ],
      }),
      throwsA(isA<EfaServerException>().having((e) => e.code, 'code', -4001)),
    );
  });

  test('a successful response ignores its warning', () {
    final json = readEfaFixtureJson('trip_bochum_dortmund');
    expect(readSystemMessages(json).single.code, -10015);
    expect(mapTripResponse(json), isNotEmpty);
  });

  test('broken shapes are FormatExceptions', () {
    for (final json in <Map<String, Object?>>[
      {'journeys': 'nope'},
      {
        'journeys': [
          {'legs': <Object?>[]},
        ],
      },
      {
        'journeys': [
          {
            'legs': [
              {'origin': stop('A', 'departure', '2026-11-02T08:00:00Z')},
            ],
          },
        ],
      },
    ]) {
      expect(
        () => mapTripResponse(json),
        throwsFormatException,
        reason: '$json',
      );
    }
  });
}
