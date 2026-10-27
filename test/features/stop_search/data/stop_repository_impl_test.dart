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
