import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/config/app_config.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_trip_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_repository_impl.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_means.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late FakeHttpAdapter adapter;

  TripRepositoryImpl repositoryAnswering(
    Future<ResponseBody> Function(RequestOptions options) handler,
  ) {
    adapter = FakeHttpAdapter(handler);
    final dio = createEfaDio(baseUrl: 'https://efa.test/openservice')
      ..httpClientAdapter = adapter;
    return TripRepositoryImpl(EfaTripRemoteSource(dio));
  }

  TripQuery query(TripTime time) =>
      TripQuery(from: bochumHbf, to: dortmundHbf, time: time);

  Failure failureOf(Result<List<Journey>> result) => switch (result) {
    Err(:final failure) => failure,
    Ok() => fail('Expected Err, got $result'),
  };

  const common = {
    'outputFormat': 'rapidJSON',
    'type_origin': 'any',
    'name_origin': 'de:05911:5194',
    'type_destination': 'any',
    'name_destination': 'de:05913:131',
    'useRealtime': '1',
    'calcNumberOfTrips': '5',
    'coordOutputFormat': 'WGS84[dd.ddddd]',
  };

  group('outside NRW', () {
    const outside = TripQuery(from: berlinHbf, to: passauHbf, time: LeaveNow());
    Future<ResponseBody> timesOut(RequestOptions options) async =>
        throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: options,
        );

    test('waits up to two minutes', () async {
      Duration? timeout;
      final repository = repositoryAnswering((options) async {
        timeout = options.receiveTimeout;
        return textResponse(readEfaFixture('trip_bochum_dortmund'));
      });
      await repository.trips(outside);
      expect(timeout, const Duration(minutes: 2));
    });

    test('with one end in NRW, the usual wait', () async {
      Duration? timeout;
      final repository = repositoryAnswering((options) async {
        timeout = options.receiveTimeout;
        return textResponse(readEfaFixture('trip_bochum_dortmund'));
      });
      await repository.trips(
        const TripQuery(from: bochumHbf, to: passauHbf, time: LeaveNow()),
      );
      expect(timeout, AppConfig.receiveTimeout);
    });

    test('no answer in time says why', () async {
      final repository = repositoryAnswering(timesOut);
      expect(
        failureOf(await repository.trips(outside)),
        isA<OutsideNrwFailure>(),
      );
    });

    test('no answer in time in NRW stays a timeout', () async {
      final repository = repositoryAnswering(timesOut);
      expect(
        failureOf(await repository.trips(query(const LeaveNow()))),
        isA<TimeoutFailure>(),
      );
    });

    test('other failures stay what they are', () async {
      final repository = repositoryAnswering(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      expect(failureOf(await repository.trips(outside)), isA<NetworkFailure>());
    });
  });

  test('leaving now sends stop IDs and no time', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(readEfaFixture('trip_bochum_dortmund')),
    );

    final result = await repository.trips(query(const LeaveNow()));

    final uri = adapter.requests.single.uri;
    expect(uri.path, '/openservice/XML_TRIP_REQUEST2');
    expect(uri.queryParameters, common);
    expect((result as Ok<List<Journey>>).value, hasLength(3));
  });

  test('depart at and arrive by send the local date and time', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(readEfaFixture('trip_bochum_dortmund')),
    );

    await repository.trips(query(DepartAt(DateTime(2026, 11, 2, 8, 5))));
    await repository.trips(query(ArriveBy(DateTime(2026, 12, 24, 17, 30))));

    expect(adapter.requests.first.uri.queryParameters, {
      ...common,
      'itdDate': '20261102',
      'itdTime': '0805',
      'itdTripDateTimeDepArr': 'dep',
    });
    expect(adapter.requests.last.uri.queryParameters, {
      ...common,
      'itdDate': '20261224',
      'itdTime': '1730',
      'itdTripDateTimeDepArr': 'arr',
    });
  });

  test('means of transport turned off are left out by VRR', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(readEfaFixture('trip_bochum_dortmund')),
    );

    await repository.trips(
      query(const LeaveNow()).withExcluded({TripMeans.ice, TripMeans.bus}),
    );

    expect(adapter.requests.single.uri.queryParameters, {
      ...common,
      'excludedMeans': 'checkbox',
      'exclMOT_5': '1',
      'exclMOT_6': '1',
      'exclMOT_7': '1',
      'exclMOT_16': '1',
      'exclMOT_17': '1',
    });
  });

  test('every means of transport stands for its product classes', () {
    expect(TripMeans.regionalTrain.productClasses, {0, 13});
    expect(TripMeans.intercity.productClasses, {14, 15});
    // Each class belongs to one means only.
    final all = [for (final m in TripMeans.values) ...m.productClasses];
    expect(all.toSet(), hasLength(all.length));
  });

  test('an EFA error message becomes ServerFailure', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(
        '{"systemMessages":[{"type":"error","code":-4001,"text":"invalid date"}]}',
      ),
    );

    expect(
      failureOf(await repository.trips(query(const LeaveNow()))),
      isA<ServerFailure>().having((f) => f.code, 'code', -4001),
    );
  });

  test('a connection error becomes NetworkFailure', () async {
    final repository = repositoryAnswering(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
      ),
    );

    expect(
      failureOf(await repository.trips(query(const LeaveNow()))),
      isA<NetworkFailure>(),
    );
  });

  test('a malformed response becomes ParseFailure', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse('{"journeys":"nope"}'),
    );

    expect(
      failureOf(await repository.trips(query(const LeaveNow()))),
      isA<ParseFailure>(),
    );
  });

  test('a new request cancels the one still running', () async {
    final firstResponse = Completer<ResponseBody>();
    var calls = 0;
    final repository = repositoryAnswering(
      (_) => ++calls == 1
          ? firstResponse.future
          : Future.value(textResponse(readEfaFixture('trip_with_walk'))),
    );

    final first = repository.trips(query(const LeaveNow()));
    // Let the first request reach the adapter before the second starts.
    await pumpEventQueue();
    final second = await repository.trips(query(const LeaveNow()));
    firstResponse.complete(textResponse('{"journeys":[]}'));

    expect(failureOf(await first), isA<CancelledFailure>());
    expect(second, isA<Ok<List<Journey>>>());
  });
}
