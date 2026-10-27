import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_state.dart';

import '../../../helpers/fake_departure_repository.dart';

const _stopId = 'de:05911:5194';

void main() {
  late FakeDepartureRepository repository;
  late DeparturesCubit cubit;
  late List<DeparturesState> states;

  setUp(() {
    repository = FakeDepartureRepository();
    cubit = DeparturesCubit(repository, _stopId);
    states = [];
    cubit.stream.listen(states.add);
  });

  tearDown(() => cubit.close());

  test('starts loading and does not request anything by itself', () {
    expect(cubit.state, isA<DeparturesLoading>());
    expect(repository.stopIds, isEmpty);
  });

  test('load shows the board for the stop', () async {
    repository.autoReply = Ok([delayedRe16, cancelledRe11]);

    await cubit.load();

    expect(repository.stopIds, [_stopId]);
    expect(
      cubit.state,
      isA<DeparturesLoaded>()
          .having((s) => s.departures, 'departures', [
            delayedRe16,
            cancelledRe11,
          ])
          .having((s) => s.refreshFailure, 'refreshFailure', isNull),
    );
  });

  test('an empty board is loaded, not an error', () async {
    repository.autoReply = const Ok([]);

    await cubit.load();

    expect(
      cubit.state,
      isA<DeparturesLoaded>().having(
        (s) => s.departures,
        'departures',
        isEmpty,
      ),
    );
  });

  test('a failed first load shows the error; retry loads again', () async {
    repository.autoReply = const Err(NetworkFailure());
    await cubit.load();
    expect(
      cubit.state,
      isA<DeparturesFailed>().having(
        (s) => s.failure,
        'failure',
        isA<NetworkFailure>(),
      ),
    );

    repository.autoReply = Ok([delayedRe16]);
    await cubit.load();

    await pumpEventQueue();
    expect(states.map((s) => s.runtimeType), [
      DeparturesLoading,
      DeparturesFailed,
      DeparturesLoading,
      DeparturesLoaded,
    ]);
  });

  test('refresh keeps the board visible instead of a spinner', () async {
    repository.autoReply = Ok([delayedRe16]);
    await cubit.load();
    await pumpEventQueue();
    states.clear();

    repository.autoReply = Ok([delayedRe16, movedU35]);
    await cubit.refresh();

    await pumpEventQueue();
    expect(states, [
      isA<DeparturesLoaded>().having((s) => s.departures, 'departures', [
        delayedRe16,
        movedU35,
      ]),
    ]);
  });

  test(
    'a failed refresh keeps the old board and reports the failure',
    () async {
      repository.autoReply = Ok([delayedRe16]);
      await cubit.load();

      repository.autoReply = const Err(TimeoutFailure());
      await cubit.refresh();

      expect(
        cubit.state,
        isA<DeparturesLoaded>()
            .having((s) => s.departures, 'departures', [delayedRe16])
            .having(
              (s) => s.refreshFailure,
              'refreshFailure',
              isA<TimeoutFailure>(),
            ),
      );
    },
  );

  test('refresh before anything loaded does a full load', () async {
    repository.autoReply = const Err(NetworkFailure());
    await cubit.load();
    await pumpEventQueue();
    states.clear();

    repository.autoReply = Ok([delayedRe16]);
    await cubit.refresh();

    await pumpEventQueue();
    expect(states.map((s) => s.runtimeType), [
      DeparturesLoading,
      DeparturesLoaded,
    ]);
  });

  test('a cancelled request leaves the state to the newer one', () async {
    final first = cubit.load();
    final second = cubit.refresh();
    // The repository cancels the first request when the second starts.
    repository.complete(0, const Err(CancelledFailure()));
    await first;
    expect(cubit.state, isA<DeparturesLoading>());

    repository.complete(1, Ok([movedU35]));
    await second;

    await pumpEventQueue();
    expect(states.whereType<DeparturesFailed>(), isEmpty);
    expect(
      cubit.state,
      isA<DeparturesLoaded>().having((s) => s.departures, 'departures', [
        movedU35,
      ]),
    );
  });

  test('ignores results that arrive after the page closed', () async {
    final load = cubit.load();
    await cubit.close();

    repository.complete(0, Ok([delayedRe16]));
    await load;

    await pumpEventQueue();
    expect(states.whereType<DeparturesLoaded>(), isEmpty);
  });
}
