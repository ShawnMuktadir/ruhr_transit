import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_state.dart';

import '../../../helpers/fake_stop_repository.dart';

/// The cubit's default debounce, which the app uses.
const _debounce = Duration(milliseconds: 300);

void main() {
  late FakeStopRepository repository;

  setUp(() => repository = FakeStopRepository());

  /// Runs [body] in fake time with a fresh cubit; returns emitted states.
  List<StopSearchState> run(void Function(StopSearchCubit, FakeAsync) body) {
    final states = <StopSearchState>[];
    fakeAsync((async) {
      final cubit = StopSearchCubit(repository);
      final subscription = cubit.stream.listen(states.add);
      body(cubit, async);
      async.flushMicrotasks();
      subscription.cancel();
      cubit.close();
      async.flushMicrotasks();
    });
    return states;
  }

  test('starts idle', () {
    expect(StopSearchCubit(repository).state, isA<StopSearchIdle>());
  });

  test('asks for addresses and places only when told to', () {
    fakeAsync((async) {
      final stopsOnly = StopSearchCubit(repository)..queryChanged('Bochum');
      final planner = StopSearchCubit(repository, includeAddresses: true)
        ..queryChanged('Kortumstr');
      async.elapse(_debounce);
      stopsOnly.close();
      planner.close();
      async.flushMicrotasks();
    });

    expect(repository.queries, ['Bochum', 'Kortumstr']);
    expect(repository.includedAddresses, [false, true]);
  });

  test('does not search for queries shorter than two characters', () {
    run((cubit, async) {
      cubit.queryChanged('B');
      cubit.queryChanged('  B  ');
      async.elapse(_debounce * 2);
    });

    expect(repository.queries, isEmpty);
  });

  test('waits for a typing pause and searches only the last query', () {
    run((cubit, async) {
      cubit.queryChanged('Bo');
      async.elapse(const Duration(milliseconds: 100));
      cubit.queryChanged('Boch');
      async.elapse(const Duration(milliseconds: 100));
      cubit.queryChanged('Bochum ');
      async.elapse(_debounce - const Duration(milliseconds: 1));
      expect(repository.queries, isEmpty);
      async.elapse(const Duration(milliseconds: 1));
    });

    expect(repository.queries, ['Bochum']);
  });

  test('emits Loading, then Loaded with the stops', () {
    final states = run((cubit, async) {
      cubit.queryChanged('Bochum');
      async.elapse(_debounce);
      repository.complete(0, const Ok([bochumHbf]));
    });

    expect(states, [
      isA<StopSearchLoading>().having((s) => s.query, 'query', 'Bochum'),
      isA<StopSearchLoaded>().having((s) => s.stops, 'stops', [bochumHbf]),
    ]);
  });

  test('emits Empty when nothing matches', () {
    final states = run((cubit, async) {
      cubit.queryChanged('xqzzqxv');
      async.elapse(_debounce);
      repository.complete(0, const Ok([]));
    });

    expect(states.last, isA<StopSearchEmpty>());
  });

  test('emits Failed and searches again on retry', () {
    final states = run((cubit, async) {
      cubit.queryChanged('Bochum');
      async.elapse(_debounce);
      repository.complete(0, const Err(NetworkFailure()));
      async.flushMicrotasks();
      cubit.retry();
      repository.complete(1, const Ok([bochumHbf]));
    });

    expect(repository.queries, ['Bochum', 'Bochum']);
    expect(states, [
      isA<StopSearchLoading>(),
      isA<StopSearchFailed>().having(
        (s) => s.failure,
        'failure',
        isA<NetworkFailure>(),
      ),
      isA<StopSearchLoading>(),
      isA<StopSearchLoaded>(),
    ]);
  });

  test('drops a slow response once a newer query was entered', () {
    final states = run((cubit, async) {
      cubit.queryChanged('Bochum');
      async.elapse(_debounce);
      cubit.queryChanged('Dortmund');
      async.elapse(_debounce);
      // Newer answer first, then the old one arrives late.
      repository.complete(1, const Ok([dortmundHbf]));
      async.flushMicrotasks();
      repository.complete(0, const Ok([bochumHbf]));
    });

    expect(states.last, isA<StopSearchLoaded>());
    expect((states.last as StopSearchLoaded).stops, [dortmundHbf]);
    expect(
      states.whereType<StopSearchLoaded>().expand((s) => s.stops),
      isNot(contains(bochumHbf)),
    );
  });

  test('clearing the query returns to Idle and drops the pending answer', () {
    final states = run((cubit, async) {
      cubit.queryChanged('Bochum');
      async.elapse(_debounce);
      cubit.queryChanged('');
      repository.complete(0, const Ok([bochumHbf]));
    });

    expect(states, [isA<StopSearchLoading>(), isA<StopSearchIdle>()]);
  });

  test('ignores a cancelled result', () {
    final states = run((cubit, async) {
      cubit.queryChanged('Bochum');
      async.elapse(_debounce);
      repository.complete(0, const Err(CancelledFailure()));
    });

    expect(states, [isA<StopSearchLoading>()]);
  });

  test('does not search after being closed', () {
    fakeAsync((async) {
      final cubit = StopSearchCubit(repository)..queryChanged('Bochum');
      cubit.close();
      async.elapse(_debounce);
    });

    expect(repository.queries, isEmpty);
  });
}
