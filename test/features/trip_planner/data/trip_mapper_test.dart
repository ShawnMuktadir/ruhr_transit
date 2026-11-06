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

    test('a walk between stops has its directions', () {
      final journeys = mapTripResponse(readEfaFixtureJson('trip_with_walk'));
      final walk = journeys.first.legs[1] as WalkLeg;

      expect(walk.steps, isNotEmpty);
      expect(walk.steps.last.turn, WalkTurn.board);
    });

    test('maps walks to and from an address or place (class 100)', () {
      final journeys = mapTripResponse(
        readEfaFixtureJson('trip_address_to_place'),
      );

      expect(journeys, hasLength(2));
      final viaTram = journeys.firstWhere((j) => j.legs.length == 4);
      final [toStation, re6, tram, toPlace] = viaTram.legs;

      expect(toStation, isA<WalkLeg>());
      toStation as WalkLeg;
      expect(toStation.origin.name, 'Bochum, Kortumstr. 10');
      expect(toStation.distanceMeters, 734);
      expect(toStation.duration, const Duration(minutes: 17));
      expect(toStation.steps, hasLength(15));
      final first = toStation.steps.first;
      expect(first.turn, WalkTurn.straight);
      // A generic "Fußweg" says nothing the walking icon does not.
      expect(first.name, isNull);
      expect(first.distanceMeters, 118);
      expect(first.duration, const Duration(seconds: 106));
      expect(
        toStation.steps.map((s) => s.turn),
        containsAllInOrder([
          WalkTurn.sharpLeft,
          WalkTurn.right,
          WalkTurn.left,
          WalkTurn.slightRight,
        ]),
      );
      expect(toStation.steps[8].name, 'Südring');
      expect(toStation.steps[8].distanceMeters, 182);
      expect(toStation.steps.last.turn, WalkTurn.board);
      expect(toStation.steps.last.name, 'Einstieg Zug RE 6 (RRX)');

      expect(toPlace, isA<WalkLeg>());
      toPlace as WalkLeg;
      expect(toPlace.destination.name, 'Essen, Rathaus Essen (Porscheplatz 1)');
      expect(toPlace.steps.first.turn, WalkTurn.alight);
      expect(toPlace.steps.map((s) => s.turn), contains(WalkTurn.uTurn));
      expect(toPlace.stationPaths.single.kind, StationPathKind.elevator);
      expect(toPlace.stationPaths.single.levelFrom, -2);
      expect(toPlace.stationPaths.single.levelTo, 0);

      // Live data for both rides.
      expect((re6 as TransitLeg).isRealtime, isTrue);
      expect((tram as TransitLeg).isRealtime, isTrue);
      expect(viaTram.isTimetableOnly, isFalse);
      // The change at Essen Hbf has no walk leg: its way is on the RE 6.
      expect(re6.transferSteps.first.turn, WalkTurn.alight);
      expect(re6.transferSteps.last.turn, WalkTurn.board);
      expect(re6.transferSteps.last.name, 'Einstieg Straßenbahn 101');
      expect(re6.transferPaths.map((p) => p.kind), [
        StationPathKind.stairs,
        StationPathKind.stairs,
        StationPathKind.stairs,
        StationPathKind.escalator,
      ]);
      expect(tram.transferSteps, isEmpty);
      // Walks are not rides.
      expect(viaTram.transfers, 1);
    });

    test('maps the stops in between with live times and platforms', () {
      final journeys = mapTripResponse(
        readEfaFixtureJson('trip_bochum_dortmund'),
      );
      final s1 = journeys.first.legs.single as TransitLeg;

      expect(s1.intermediateStops.map((stop) => stop.name), [
        'Bochum Langendreer West',
        'Bochum Langendreer S',
        'Dortmund Kley S',
        'Dortmund Oespel',
        'Dortmund Universität S',
        'Dortmund Dorstfeld Süd S',
        'Dortmund Dorstfeld S',
      ]);
      final first = s1.intermediateStops.first;
      // The departure, which is what a passenger waits for.
      expect(first.plannedTime, DateTime.utc(2026, 10, 25, 17, 18));
      expect(first.estimatedTime, DateTime.utc(2026, 10, 25, 17, 22));
      expect(first.platform, '2');
      // An express without stops in between.
      expect(
        (journeys[1].legs.single as TransitLeg).intermediateStops,
        isEmpty,
      );
    });

    test('cleans stop names and allows stops without platform', () {
      final journeys = mapTripResponse(readEfaFixtureJson('trip_with_walk'));
      final u35 = journeys.first.legs.first as TransitLeg;

      // EFA sends "Bochum  Gesundheitscampus" with two spaces.
      expect(u35.intermediateStops.first.name, 'Bochum Gesundheitscampus');
      expect(u35.intermediateStops.first.platform, isNull);
      expect(u35.intermediateStops, hasLength(6));
    });

    test('maps notices once per journey, important ones first', () {
      final journeys = mapTripResponse(
        readEfaFixtureJson('trip_bochum_dortmund'),
      );

      final notices = journeys[2].notices;
      expect(notices, hasLength(5));
      expect(notices.map((n) => n.id).toSet(), hasLength(5));
      expect(notices.first.kind, TripNoticeKind.trip);
      expect(notices.first.text, startsWith('Keine fahrzeuggebundene'));
      final lift = notices.last;
      expect(lift.kind, TripNoticeKind.facilities);
      expect(lift.title, 'Haltestelle Bochum Hbf: Aufzug außer Betrieb.');
      expect(lift.priority, TripNoticePriority.normal);
      expect(lift.severity, TripNoticeSeverity.note);
      // About the ride itself, so a warning and first.
      expect(notices.first.severity, TripNoticeSeverity.warning);
      expect(journeys[2].hasWarning, isTrue);
      expect(journeys[0].hasWarning, isFalse);
      // EFA's urlText is empty here.
      expect(lift.summary, isNull);
    });

    test('turns HTML notices into plain text with their summary', () {
      final journeys = mapTripResponse(readEfaFixtureJson('trip_with_walk'));

      final notices = journeys[3].notices;
      expect(notices.map((n) => n.kind), [
        TripNoticeKind.stop,
        TripNoticeKind.line,
      ]);
      final line = notices.last;
      expect(line.priority, TripNoticePriority.low);
      expect(line.severity, TripNoticeSeverity.background);
      expect(line.title, 'Haltestellenveränderungen durch Baumaßnahme');
      expect(line.summary, startsWith('Linien E24, E30, E32, E34, E71'));
      expect(line.text, isNot(contains('<')));
      expect(line.text, isNot(contains('&')));
      expect(line.text, contains('Zusätzlich bedient werden:'));
      // The same notice on two legs counts once.
      expect(journeys[2].notices, hasLength(1));
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

  group('a long-distance train without any line name', () {
    // As seen live, Bochum Hbf to Essen Hbf, reduced to what matters.
    Map<String, Object?> journey(Map<String, Object?> transportation) => {
      'legs': [
        {
          'origin': {
            'name': 'Bochum Hbf',
            'departureTimePlanned': '2026-11-06T19:48:00Z',
          },
          'destination': {
            'name': 'Essen Hauptbahnhof',
            'arrivalTimePlanned': '2026-11-06T20:00:00Z',
          },
          'transportation': transportation,
        },
      ],
    };
    const nameless = <String, Object?>{
      'id': 'ddb:98042: :R:j26',
      'product': {'id': 0, 'class': 16, 'name': 'Zug', 'iconId': 6},
      'destination': {'name': 'Stuttgart Hauptbahnhof'},
      'properties': {'tripCode': 235},
    };

    test('is shown by its product, not by its trip code', () {
      final journeys = mapTripResponse({
        'journeys': [journey(nameless)],
      });
      final leg = journeys.single.legs.single as TransitLeg;
      expect(leg.line, 'Zug');
      expect(leg.direction, 'Stuttgart Hauptbahnhof');
    });

    test('an unreadable journey leaves the others in place', () {
      final journeys = mapTripResponse({
        'journeys': [
          journey(const {'id': 'no name and no product'}),
          journey(nameless),
          const {'legs': <Object?>[]},
        ],
      });
      expect(journeys, hasLength(1));
    });

    test('with no readable journey at all it is still an error', () {
      expect(
        () => mapTripResponse({
          'journeys': [
            journey(const {'id': 'no name and no product'}),
          ],
        }),
        throwsFormatException,
      );
    });
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
