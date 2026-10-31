import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/departures/data/departure_repository_impl.dart';
import 'package:ruhr_transit/features/departures/data/efa_departure_remote_source.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fixtures.dart';

const _bochumHbf = 'de:05911:5194';

void main() {
  late FakeHttpAdapter adapter;

  DepartureRepositoryImpl repositoryAnswering(
    Future<ResponseBody> Function(RequestOptions options) handler,
  ) {
    adapter = FakeHttpAdapter(handler);
    final dio = createEfaDio(baseUrl: 'https://efa.test/openservice')
      ..httpClientAdapter = adapter;
    return DepartureRepositoryImpl(EfaDepartureRemoteSource(dio));
  }

  Failure failureOf(Result<List<Departure>> result) => switch (result) {
    Err(:final failure) => failure,
    Ok() => fail('Expected Err, got $result'),
  };

  test('sends a departure monitor request and maps the response', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(readEfaFixture('dm_bochum_hbf')),
    );

    final result = await repository.departuresAt(_bochumHbf);

    final uri = adapter.requests.single.uri;
    expect(uri.path, '/openservice/XML_DM_REQUEST');
    expect(uri.queryParameters, {
      'outputFormat': 'rapidJSON',
      'mode': 'direct',
      'type_dm': 'stop',
      'name_dm': _bochumHbf,
      'useRealtime': '1',
      'depType': 'stopEvents',
      'limit': '30',
    });
    expect((result as Ok<List<Departure>>).value, hasLength(20));
  });

  test('an EFA error message becomes ServerFailure', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(
        '{"systemMessages":[{"type":"error","code":-8010,"text":""}]}',
      ),
    );

    expect(
      failureOf(await repository.departuresAt(_bochumHbf)),
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

    expect(
      failureOf(await repository.departuresAt(_bochumHbf)),
      isA<NetworkFailure>(),
    );
  });

  test('a malformed response becomes ParseFailure', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse('{"stopEvents":"nope"}'),
    );

    expect(
      failureOf(await repository.departuresAt(_bochumHbf)),
      isA<ParseFailure>(),
    );
  });

  test('a new request cancels the one still running', () async {
    final firstResponse = Completer<ResponseBody>();
    var calls = 0;
    final repository = repositoryAnswering(
      (_) => ++calls == 1
          ? firstResponse.future
          : Future.value(textResponse(readEfaFixture('dm_bochum_hbf'))),
    );

    final first = repository.departuresAt(_bochumHbf);
    // Both requests look the same, so let the first one reach the adapter
    // before starting the second; otherwise Dio drops it before sending.
    await pumpEventQueue();
    expect(adapter.requests, hasLength(1));
    final second = await repository.departuresAt(_bochumHbf);
    firstResponse.complete(textResponse('{"stopEvents":[]}'));

    expect(failureOf(await first), isA<CancelledFailure>());
    expect(second, isA<Ok<List<Departure>>>());
  });
}
