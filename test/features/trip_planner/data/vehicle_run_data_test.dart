import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_run_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/run_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/data/vehicle_run_repository_impl.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fixtures.dart';

void main() {
  group('mapRunResponse with a recorded run', () {
    final run = mapRunResponse(readEfaFixtureJson('stopseq_run'));

    test('maps the whole run with live times', () {
      // RE1 from Hamm to Aachen, recorded 2026-11-02.
      expect(run.stops, hasLength(25));
      expect(run.isRealtime, isTrue);
      expect(run.stops.first.name, 'Hamm (Westf.) Hbf');
      expect(run.stops.first.arrivalPlanned, isNull);
      expect(
        run.stops.first.departurePlanned,
        DateTime.utc(2026, 11, 2, 16, 20),
      );
      expect(
        run.stops.first.departureEstimated,
        DateTime.utc(2026, 11, 2, 16, 21, 36),
      );
      expect(run.stops.last.name, 'Aachen, Hbf');
      expect(run.stops.last.departurePlanned, isNull);
      expect(run.stops.last.platform, '2');
      final kamen = run.stops[1];
      expect(kamen.arrival, DateTime.utc(2026, 11, 2, 16, 31));
      expect(kamen.departure, DateTime.utc(2026, 11, 2, 16, 31, 36));
    });

    test('finds where the user boards and gets off', () {
      expect(run.indexOf('de:05911:5194:91:3'), 6);
      expect(run.stops[6].name, 'Bochum Hbf');
      expect(run.indexOf('de:05113:9289:90:2'), 8);
    });

    test('rejects a response without a run', () {
      expect(() => mapRunResponse(const {}), throwsFormatException);
      expect(
        () => mapRunResponse(const {
          'leg': {'stopSequence': <Object?>[]},
        }),
        throwsFormatException,
      );
    });
  });

  test('a trip leg carries what is needed to request its run', () {
    final journeys = mapTripResponse(
      readEfaFixtureJson('trip_bochum_dortmund'),
    );
    final s1 = journeys.first.legs.single as TransitLeg;

    final key = s1.runKey!;
    expect(key.lineId, isNotEmpty);
    expect(key.tripCode, isNotEmpty);
    expect(key.stopId, s1.originId!.id);
    expect(key.plannedDeparture, s1.origin.plannedTime);
    expect(s1.originId!.parentId, 'de:05911:5194');
  });

  group('VehicleRunRepositoryImpl', () {
    final key = RunKey(
      lineId: 'ddb:90RE1: :H:j26',
      tripCode: '199',
      stopId: 'de:05911:5194:91:3',
      plannedDeparture: DateTime.utc(2026, 11, 2, 16, 55),
    );

    test('requests the whole run for the leg', () async {
      late Uri requested;
      final adapter = FakeHttpAdapter((options) async {
        requested = options.uri;
        return textResponse(readEfaFixture('stopseq_run'));
      });
      final dio = createEfaDio(baseUrl: 'https://efa.test/openservice')
        ..httpClientAdapter = adapter;

      final result = await VehicleRunRepositoryImpl(
        EfaRunRemoteSource(dio),
      ).run(key);

      expect(result, isA<Ok<VehicleRun>>());
      expect(requested.path, endsWith('XML_STOPSEQCOORD_REQUEST'));
      final local = key.plannedDeparture.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      expect(requested.queryParameters, {
        'outputFormat': 'rapidJSON',
        // The space survives the round trip.
        'line': 'ddb:90RE1: :H:j26',
        'stop': 'de:05911:5194:91:3',
        'tripCode': '199',
        'date': '${local.year}${two(local.month)}${two(local.day)}',
        'time': '${two(local.hour)}${two(local.minute)}',
        'tStOTType': 'all',
        'useRealtime': '1',
        'coordOutputFormat': 'WGS84[dd.ddddd]',
      });
    });

    test('an unusable answer is a parse failure', () async {
      final adapter = FakeHttpAdapter((_) async => textResponse('{}'));
      final dio = createEfaDio(baseUrl: 'https://efa.test/openservice')
        ..httpClientAdapter = adapter;

      final result = await VehicleRunRepositoryImpl(
        EfaRunRemoteSource(dio),
      ).run(key);

      expect(result, isA<Err<VehicleRun>>());
      expect((result as Err<VehicleRun>).failure, isA<ParseFailure>());
    });
  });
}
