import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/nearby_stops/data/efa_coord_remote_source.dart';
import 'package:ruhr_transit/features/nearby_stops/data/nearby_stops_repository_impl.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late FakeHttpAdapter adapter;

  NearbyStopsRepositoryImpl repositoryAnswering(
    Future<ResponseBody> Function(RequestOptions options) handler,
  ) {
    adapter = FakeHttpAdapter(handler);
    final dio = createEfaDio(baseUrl: 'https://efa.test/openservice')
      ..httpClientAdapter = adapter;
    return NearbyStopsRepositoryImpl(EfaCoordRemoteSource(dio));
  }

  Future<Result<List<NearbyStop>>> nearBochumHbf(
    NearbyStopsRepositoryImpl repository,
  ) => repository.stopsNear(latitude: 51.479466, longitude: 7.223335);

  Failure failureOf(Result<List<NearbyStop>> result) => switch (result) {
    Err(:final failure) => failure,
    Ok() => fail('Expected Err, got $result'),
  };

  test('sends a coordinate request, longitude first', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(readEfaFixture('coord_nearby_bochum_hbf')),
    );

    final result = await nearBochumHbf(repository);

    final uri = adapter.requests.single.uri;
    expect(uri.path, '/openservice/XML_COORD_REQUEST');
    expect(uri.queryParameters, {
      'outputFormat': 'rapidJSON',
      'coord': '7.223335:51.479466:WGS84[dd.ddddd]',
      'coordOutputFormat': 'WGS84[dd.ddddd]',
      'inclFilter': '1',
      'type_1': 'STOP',
      'radius_1': '1000',
      'max': '20',
    });
    expect((result as Ok<List<NearbyStop>>).value, hasLength(5));
  });

  test('an EFA error message becomes ServerFailure', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(
        '{"systemMessages":[{"type":"error","code":-8010,"text":""}]}',
      ),
    );

    expect(
      failureOf(await nearBochumHbf(repository)),
      isA<ServerFailure>().having((f) => f.code, 'code', -8010),
    );
  });

  test('a connection error becomes NetworkFailure', () async {
    final repository = repositoryAnswering(
      (options) => throw DioException.connectionError(
        requestOptions: options,
        reason: 'Failed host lookup',
      ),
    );

    expect(failureOf(await nearBochumHbf(repository)), isA<NetworkFailure>());
  });

  test('a malformed response becomes ParseFailure', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse('{"locations":"nope"}'),
    );

    expect(failureOf(await nearBochumHbf(repository)), isA<ParseFailure>());
  });

  test('a new request cancels the one still running', () async {
    final firstResponse = Completer<ResponseBody>();
    var calls = 0;
    final repository = repositoryAnswering(
      (_) => ++calls == 1
          ? firstResponse.future
          : Future.value(textResponse(readEfaFixture('coord_nearby_none'))),
    );

    final first = nearBochumHbf(repository);
    // Let the first request reach the adapter before the second starts.
    await pumpEventQueue();
    final second = await nearBochumHbf(repository);
    firstResponse.complete(textResponse('{"locations":[]}'));

    expect(failureOf(await first), isA<CancelledFailure>());
    expect(second, isA<Ok<List<NearbyStop>>>());
  });
}
