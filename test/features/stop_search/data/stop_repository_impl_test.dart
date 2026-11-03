import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/stop_search/data/efa_stop_remote_source.dart';
import 'package:ruhr_transit/features/stop_search/data/stop_repository_impl.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fixtures.dart';

void main() {
  late FakeHttpAdapter adapter;

  StopRepositoryImpl repositoryAnswering(
    Future<ResponseBody> Function(RequestOptions options) handler,
  ) {
    adapter = FakeHttpAdapter(handler);
    final dio = createEfaDio(baseUrl: 'https://efa.test/openservice')
      ..httpClientAdapter = adapter;
    return StopRepositoryImpl(EfaStopRemoteSource(dio));
  }

  Failure failureOf(Result<List<Stop>> result) => switch (result) {
    Err(:final failure) => failure,
    Ok() => fail('Expected Err, got $result'),
  };

  group('locationAt', () {
    test('asks for the place at a point, about 10 m exact', () async {
      final repository = repositoryAnswering(
        (_) async => textResponse(readEfaFixture('stopfinder_coord')),
      );

      final result = await repository.locationAt(
        latitude: 51.476312,
        longitude: 7.216498,
      );

      final uri = adapter.requests.single.uri;
      expect(uri.path, '/openservice/XML_STOPFINDER_REQUEST');
      expect(uri.queryParameters, {
        'outputFormat': 'rapidJSON',
        'type_sf': 'coord',
        // Longitude first.
        'name_sf': '7.2165:51.4763:WGS84[dd.ddddd]',
        'coordOutputFormat': 'WGS84[dd.ddddd]',
      });
      final address = (result as Ok<Stop?>).value!;
      expect(address.kind, LocationKind.address);
      expect(address.name, 'Kortumstr. 10');
      expect(address.fullName, 'Innenstadt (Bochum), Kortumstr. 10');
      expect(address.locality, 'Innenstadt (Bochum)');
      expect(address.id, startsWith('coord:'));
    });

    test('nothing there is Ok(null)', () async {
      final repository = repositoryAnswering(
        (_) async => textResponse(readEfaFixture('stopfinder_no_match')),
      );

      final result = await repository.locationAt(latitude: 0, longitude: 0);

      expect(result, isA<Ok<Stop?>>().having((r) => r.value, 'value', null));
    });

    test('offline is a NetworkFailure', () async {
      final repository = repositoryAnswering(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      final result = await repository.locationAt(latitude: 51, longitude: 7);

      expect(
        result,
        isA<Err<Stop?>>().having(
          (r) => r.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
      );
    });
  });

  test('sends a stop finder request and maps the response', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(readEfaFixture('stopfinder_bochum_hbf')),
    );

    final result = await repository.searchStops('Bochum Hbf');

    final uri = adapter.requests.single.uri;
    expect(uri.path, '/openservice/XML_STOPFINDER_REQUEST');
    expect(uri.queryParameters, {
      'outputFormat': 'rapidJSON',
      'type_sf': 'any',
      'name_sf': 'Bochum Hbf',
      'coordOutputFormat': 'WGS84[dd.ddddd]',
    });
    expect(result, isA<Ok<List<Stop>>>());
    expect((result as Ok<List<Stop>>).value, hasLength(3));
  });

  test('HTTP 500 becomes ServerFailure with the status code', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse('oops', statusCode: 500),
    );

    final failure = failureOf(await repository.searchStops('Bochum'));

    expect(failure, isA<ServerFailure>().having((f) => f.code, 'code', 500));
  });

  test(
    'an EFA error message becomes ServerFailure with the EFA code',
    () async {
      final repository = repositoryAnswering(
        (_) async => textResponse(
          '{"systemMessages":[{"type":"error","code":-8010,"text":""}]}',
        ),
      );

      final failure = failureOf(await repository.searchStops('Bochum'));

      expect(
        failure,
        isA<ServerFailure>()
            .having((f) => f.code, 'code', -8010)
            .having((f) => f.message, 'message', isNull),
      );
    },
  );

  test('a timeout becomes TimeoutFailure', () async {
    final repository = repositoryAnswering(
      (options) => throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 15),
        requestOptions: options,
      ),
    );

    expect(
      failureOf(await repository.searchStops('Bochum')),
      isA<TimeoutFailure>(),
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
      failureOf(await repository.searchStops('Bochum')),
      isA<NetworkFailure>(),
    );
  });

  test('a body that is not JSON becomes ParseFailure', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse('<html>maintenance</html>'),
    );

    expect(
      failureOf(await repository.searchStops('Bochum')),
      isA<ParseFailure>(),
    );
  });

  test('a new search cancels the one still running', () async {
    final firstResponse = Completer<ResponseBody>();
    final repository = repositoryAnswering(
      (options) => options.queryParameters['name_sf'] == 'Boc'
          ? firstResponse.future
          : Future.value(textResponse(readEfaFixture('stopfinder_bochum_hbf'))),
    );

    final first = repository.searchStops('Boc');
    final second = await repository.searchStops('Bochum Hbf');
    // The server answering late must not turn the cancel into a success.
    firstResponse.complete(textResponse('{"locations":[]}'));

    expect(failureOf(await first), isA<CancelledFailure>());
    expect(second, isA<Ok<List<Stop>>>());
  });
}
