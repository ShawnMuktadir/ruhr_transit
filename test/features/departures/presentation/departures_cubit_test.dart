import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_state.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_widget_sync.dart';

const _stopId = 'de:05911:5194';

void main() {
  late FakeDepartureRepository repository;
  late DeparturesCubit cubit;
  late List<DeparturesState> states;
  late DateTime now;

  setUp(() {
    repository = FakeDepartureRepository();
    now = boardTime;
    cubit = DeparturesCubit(repository, _stopId, now: () => now);
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
          .having((s) => s.fetchedAt, 'fetchedAt', boardTime)
          .having((s) => s.refreshFailure, 'refreshFailure', isNull),
    );
  });

  test('shows a fresh board as sent, even if the clock is ahead', () async {
    now = DateTime.utc(2026, 10, 25, 18);
    repository.autoReply = Ok([delayedRe16]);

    await cubit.load();

    expect(
      cubit.state,
      isA<DeparturesLoaded>().having((s) => s.departures, 'departures', [
        delayedRe16,
      ]),
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

  group('when loading fails', () {
    final savedAt = DateTime.utc(2026, 10, 25, 16, 50);

    setUp(() {
      repository
        ..autoReply = const Err(NetworkFailure())
        ..savedBoard = DepartureBoard([
          delayedRe16,
          cancelledRe11,
          movedU35,
        ], fetchedAt: savedAt);
    });

    test('shows the saved board with the failure', () async {
      await cubit.load();

      expect(
        cubit.state,
        isA<DeparturesLoaded>()
            .having((s) => s.departures, 'departures', [
              delayedRe16,
              cancelledRe11,
              movedU35,
            ])
            .having((s) => s.fetchedAt, 'fetchedAt', savedAt)
            .having((s) => s.isOutdated, 'isOutdated', isTrue)
            .having(
              (s) => s.refreshFailure,
              'refreshFailure',
              isA<NetworkFailure>(),
            ),
      );
    });

    test('drops saved departures that have left, by estimate', () async {
      // RE11 was planned for 17:24; RE16 was planned for 17:13 but is
      // expected at 17:25.
      now = DateTime.utc(2026, 10, 25, 17, 24, 30);

      await cubit.load();

      expect(
        cubit.state,
        isA<DeparturesLoaded>().having((s) => s.departures, 'departures', [
          delayedRe16,
          movedU35,
        ]),
      );
    });

    test('shows the error if every saved departure has left', () async {
      now = DateTime.utc(2026, 10, 25, 18);

      await cubit.load();

      expect(
        cubit.state,
        isA<DeparturesFailed>().having(
          (s) => s.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
      );
    });

    test('shows the error if nothing is saved', () async {
      repository.savedBoard = null;

      await cubit.load();

      expect(cubit.state, isA<DeparturesFailed>());
    });

    test('a failed refresh drops departures that left meanwhile', () async {
      repository.autoReply = Ok([delayedRe16, movedU35]);
      await cubit.load();

      now = DateTime.utc(2026, 10, 25, 17, 30);
      repository.autoReply = const Err(TimeoutFailure());
      await cubit.refresh();

      expect(
        cubit.state,
        isA<DeparturesLoaded>()
            // The board of this page, not the saved one.
            .having((s) => s.departures, 'departures', [movedU35])
            .having((s) => s.fetchedAt, 'fetchedAt', boardTime)
            .having(
              (s) => s.refreshFailure,
              'refreshFailure',
              isA<TimeoutFailure>(),
            ),
      );
    });

    test('a newer load wins over a slow read of the saved board', () async {
      final savedBoard = repository.savedBoard;
      final pending = repository.pendingLastBoard = Completer();
      final first = cubit.load();
      await pumpEventQueue();

      repository.autoReply = Ok([movedU35]);
      await cubit.load();
      pending.complete(savedBoard);
      await first;

      expect(
        cubit.state,
        isA<DeparturesLoaded>()
            .having((s) => s.departures, 'departures', [movedU35])
            .having((s) => s.refreshFailure, 'refreshFailure', isNull),
      );
    });
  });

  group('home-screen widget', () {
    test('shows the stop with the board on screen', () async {
      final widgetSync = FakeWidgetSync()..canAdd = true;
      final withWidget = DeparturesCubit(
        repository,
        _stopId,
        now: () => now,
        widgetSync: widgetSync,
      );
      addTearDown(withWidget.close);
      repository.autoReply = Ok([delayedRe16]);
      await withWidget.load();

      expect(withWidget.hasWidget, isTrue);
      expect(await withWidget.showOnWidget(bochumHbf), isTrue);
      final (stop, board) = widgetSync.shown.single;
      expect(stop, bochumHbf);
      expect(board?.departures, [delayedRe16]);

      await withWidget.addWidget();
      expect(widgetSync.addCount, 1);
    });

    test('without a widget there is nothing to show', () async {
      expect(cubit.hasWidget, isFalse);
      expect(await cubit.showOnWidget(bochumHbf), isFalse);
    });
  });
}
