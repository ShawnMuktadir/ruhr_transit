import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/core/network/request_result.dart';

void main() {
  group('requestResult', () {
    Future<Failure> failureOf(Object error) async =>
        switch (await requestResult<int>(() => Future.error(error))) {
          Err(:final failure) => failure,
          Ok() => fail('expected a failure'),
        };

    test('an answer is Ok', () async {
      expect(await requestResult(() async => 42), isA<Ok<int>>());
    });

    test('a timeout, a server error and an unreadable answer', () async {
      final request = RequestOptions(path: '/');
      expect(
        await failureOf(
          DioException(
            requestOptions: request,
            type: DioExceptionType.receiveTimeout,
          ),
        ),
        isA<TimeoutFailure>(),
      );
      expect(
        await failureOf(const EfaServerException(-8010, 'no stop')),
        isA<ServerFailure>()
            .having((f) => f.code, 'code', -8010)
            .having((f) => f.message, 'message', 'no stop'),
      );
      expect(
        await failureOf(const FormatException('not JSON')),
        isA<ParseFailure>().having((f) => f.message, 'message', 'not JSON'),
      );
    });

    test('other errors are bugs, not failures', () {
      expect(
        requestResult<int>(() async => throw StateError('bug')),
        throwsStateError,
      );
    });
  });

  group('LatestRequest', () {
    test('a new request cancels the one still running', () async {
      final latest = LatestRequest();
      final tokens = <CancelToken>[];
      final first = latest.run((token) async {
        tokens.add(token);
        await Future<void>.delayed(Duration.zero);
        return 1;
      });
      final second = latest.run((token) async {
        tokens.add(token);
        return 2;
      });

      expect(await second, 2);
      expect(await first, 1);
      expect(tokens[0].isCancelled, isTrue);
      expect(tokens[1].isCancelled, isFalse);
    });

    test('a finished request is not cancelled by the next', () async {
      final latest = LatestRequest();
      late CancelToken done;
      await latest.run((token) async => done = token);
      await latest.run((token) async => 0);

      expect(done.isCancelled, isFalse);
    });
  });
}
