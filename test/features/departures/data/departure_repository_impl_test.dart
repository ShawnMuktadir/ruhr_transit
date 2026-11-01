import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/departures/data/departure_cache.dart';
import 'package:ruhr_transit/features/departures/data/departure_repository_impl.dart';
import 'package:ruhr_transit/features/departures/data/efa_departure_remote_source.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../helpers/fake_http_adapter.dart';
import '../../../helpers/fixtures.dart';

const _bochumHbf = 'de:05911:5194';
final _now = DateTime.utc(2026, 10, 25, 17, 2);

/// Storage that fails, e.g. because the device is full.
class _BrokenCache extends DepartureCache {
  _BrokenCache() : super(SharedPreferencesAsync());

  @override
  Future<DepartureBoard?> read(String stopId) =>
      Future.error(Exception('disk error'));

  @override
  Future<void> write(String stopId, DepartureBoard board) =>
      Future.error(Exception('disk full'));
}

void main() {
  late FakeHttpAdapter adapter;
  late DepartureCache cache;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    cache = DepartureCache(SharedPreferencesAsync());
  });

  late List<(String, DepartureBoard)> passedOn;

  DepartureRepositoryImpl repositoryAnswering(
    Future<ResponseBody> Function(RequestOptions options) handler,
  ) {
    passedOn = [];
    adapter = FakeHttpAdapter(handler);
    final dio = createEfaDio(baseUrl: 'https://efa.test/openservice')
      ..httpClientAdapter = adapter;
    return DepartureRepositoryImpl(
      EfaDepartureRemoteSource(dio),
      cache,
      now: () => _now,
      onBoardFetched: (stopId, board) async => passedOn.add((stopId, board)),
    );
  }

  Failure failureOf(Result<DepartureBoard> result) => switch (result) {
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
    final board = (result as Ok<DepartureBoard>).value;
    expect(board.departures, hasLength(20));
    expect(board.fetchedAt, _now);
  });

  test('saves a fetched board for lastBoard', () async {
    final repository = repositoryAnswering(
      (_) async => textResponse(readEfaFixture('dm_bochum_hbf')),
    );
    expect(await repository.lastBoard(_bochumHbf), isNull);

    await repository.departuresAt(_bochumHbf);

    final saved = await repository.lastBoard(_bochumHbf);
    expect(saved?.departures, hasLength(20));
    expect(saved?.fetchedAt, _now);
  });

  test('passes fetched boards on, but not failures', () async {
    var fail = false;
    final repository = repositoryAnswering(
      (options) async => fail
          ? throw DioException.connectionError(
              requestOptions: options,
              reason: 'Failed host lookup',
            )
          : textResponse(readEfaFixture('dm_bochum_hbf')),
    );

    final board = (await repository.departuresAt(_bochumHbf)) as Ok;
    fail = true;
    await repository.departuresAt(_bochumHbf);

    expect(passedOn, hasLength(1));
    expect(passedOn.single.$1, _bochumHbf);
    expect(passedOn.single.$2, same(board.value));
  });

  test('a failed fetch keeps the saved board', () async {
    var fail = false;
    final repository = repositoryAnswering(
      (options) async => fail
          ? throw DioException.connectionError(
              requestOptions: options,
              reason: 'Failed host lookup',
            )
          : textResponse(readEfaFixture('dm_bochum_hbf')),
    );
    await repository.departuresAt(_bochumHbf);

    fail = true;
    await repository.departuresAt(_bochumHbf);

    expect((await repository.lastBoard(_bochumHbf))?.departures, hasLength(20));
  });

  test('broken storage neither fails the fetch nor lastBoard', () async {
    cache = _BrokenCache();
    final repository = repositoryAnswering(
      (_) async => textResponse(readEfaFixture('dm_bochum_hbf')),
    );

    expect(
      await repository.departuresAt(_bochumHbf),
      isA<Ok<DepartureBoard>>(),
    );
    expect(await repository.lastBoard(_bochumHbf), isNull);
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
    expect(second, isA<Ok<DepartureBoard>>());
    // The saved board is the newer answer, not the empty cancelled one.
    expect((await repository.lastBoard(_bochumHbf))?.departures, hasLength(20));
  });
}
