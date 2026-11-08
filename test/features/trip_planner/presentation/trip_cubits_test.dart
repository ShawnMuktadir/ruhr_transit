import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_state.dart';

import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_trip_repository.dart';

void main() {
  group('TripFormCubit', () {
    final now = DateTime(2026, 11, 2, 8);
    late TripFormCubit cubit;

    setUp(() => cubit = TripFormCubit(now: () => now));
    tearDown(() => cubit.close());

    test('can search only with two different stops', () {
      expect(cubit.state.query, isNull);

      cubit.setFrom(bochumHbf);
      expect(cubit.state.query, isNull);

      cubit.setTo(bochumHbf);
      expect(cubit.state.isSameStop, isTrue);
      expect(cubit.state.query, isNull);

      cubit.setTo(dortmundHbf);
      expect(cubit.state.isSameStop, isFalse);
      expect(cubit.state.query?.from, bochumHbf);
      expect(cubit.state.query?.to, dortmundHbf);
      expect(cubit.state.query?.time, isA<LeaveNow>());
    });

    test('swap exchanges start and destination', () {
      cubit
        ..setFrom(bochumHbf)
        ..setTo(dortmundHbf)
        ..swap();

      expect(cubit.state.from, dortmundHbf);
      expect(cubit.state.to, bochumHbf);
    });

    test('depart and arrive start from now and keep a chosen time', () {
      cubit.departAt();
      expect(
        cubit.state.time,
        isA<DepartAt>().having((t) => t.time, 'time', now),
      );

      final evening = DateTime(2026, 11, 2, 18, 30);
      cubit
        ..departAt(evening)
        ..arriveBy();
      expect(
        cubit.state.time,
        isA<ArriveBy>().having((t) => t.time, 'time', evening),
      );

      cubit.leaveNow();
      expect(cubit.state.time, isA<LeaveNow>());
    });

    test('changing the time keeps the stops', () {
      cubit
        ..setFrom(bochumHbf)
        ..setTo(dortmundHbf)
        ..arriveBy();

      expect(cubit.state.query?.time, isA<ArriveBy>());
    });
  });

  group('TripResultsCubit', () {
    /// A one-leg journey leaving [minute] minutes after 07:30.
    Journey ride(int minute) => Journey([
      TransitLeg(
        line: 'RE$minute',
        direction: 'Dortmund',
        origin: TripStop(
          name: 'Bochum Hbf',
          plannedTime: DateTime.utc(
            2026,
            11,
            2,
            7,
            30,
          ).add(Duration(minutes: minute)),
        ),
        destination: TripStop(
          name: 'Dortmund Hbf',
          plannedTime: DateTime.utc(
            2026,
            11,
            2,
            7,
            45,
          ).add(Duration(minutes: minute)),
        ),
      ),
    ]);

    const query = TripQuery(from: bochumHbf, to: dortmundHbf, time: LeaveNow());
    late FakeTripRepository repository;
    late TripResultsCubit cubit;

    // Before every sample journey leaves.
    var now = DateTime.utc(2026, 11, 2, 7);

    setUp(() {
      now = DateTime.utc(2026, 11, 2, 7);
      repository = FakeTripRepository();
      cubit = TripResultsCubit(repository, query, now: () => now);
    });
    tearDown(() => cubit.close());

    test('loads the journeys for the query', () async {
      await cubit.load();

      expect(repository.queries.first, query);
      expect(
        cubit.state,
        isA<TripResultsLoaded>().having((s) => s.journeys, 'journeys', [
          directS1,
          withWalk,
        ]),
      );
    });

    test('leaving now drops journeys that already left', () async {
      // directS1 leaves 07:17 as expected, withWalk 07:21.
      now = DateTime.utc(2026, 11, 2, 7, 19);

      await cubit.load();

      expect(
        cubit.state,
        isA<TripResultsLoaded>().having((s) => s.journeys, 'journeys', [
          withWalk,
        ]),
      );
    });

    test('a journey leaving a minute ago is still shown', () async {
      now = DateTime.utc(2026, 11, 2, 7, 18);

      await cubit.load();

      expect((cubit.state as TripResultsLoaded).journeys, hasLength(2));
    });

    test('a chosen departure time keeps every journey', () async {
      now = DateTime.utc(2026, 11, 2, 9);
      cubit = TripResultsCubit(
        repository,
        query.withTime(DepartAt(DateTime(2026, 11, 2, 7))),
        now: () => now,
      );

      await cubit.load();

      expect((cubit.state as TripResultsLoaded).journeys, hasLength(2));
    });

    test('no journeys is loaded, not an error', () async {
      repository.replies = [const Ok([])];

      await cubit.load();

      expect(
        cubit.state,
        isA<TripResultsLoaded>().having((s) => s.journeys, 'journeys', isEmpty),
      );
    });

    test('a failure shows the error; retry loads again', () async {
      repository.replies = [
        const Err(NetworkFailure()),
        Ok([directS1]),
      ];

      await cubit.load();
      expect(cubit.state, isA<TripResultsFailed>());

      await cubit.load();
      expect(cubit.state, isA<TripResultsLoaded>());
    });

    test(
      'fills up with later trips, a minute after the last departure',
      () async {
        repository.replies = [
          Ok([directS1, withWalk]),
          // EFA may send a journey again; it is shown once.
          Ok([withWalk, laterRe11]),
        ];
        await cubit.load();

        final laterQuery = repository.queries[1];
        expect(laterQuery.from, bochumHbf);
        expect(
          laterQuery.time,
          isA<DepartAt>().having(
            (t) => t.time,
            'time',
            withWalk.departure.time.toLocal().add(const Duration(minutes: 1)),
          ),
        );
        expect(
          cubit.state,
          isA<TripResultsLoaded>()
              .having((s) => s.journeys, 'journeys', [
                directS1,
                withWalk,
                laterRe11,
              ])
              .having((s) => s.isLoadingLater, 'isLoadingLater', isFalse),
        );
        // The third answer brought nothing new, so it stopped there.
        expect(repository.queries, hasLength(3));
      },
    );

    test('shows the first trips while filling up', () async {
      repository.replies = [
        Ok([directS1]),
      ];
      // The second request, the automatic fill, waits until completed.
      final fill = Completer<Result<List<Journey>>>();
      var calls = 0;
      repository.onQuery = () {
        if (++calls == 2) repository.pending = fill;
      };

      final load = cubit.load();
      await pumpEventQueue();
      expect(
        cubit.state,
        isA<TripResultsLoaded>()
            .having((s) => s.journeys, 'journeys', [directS1])
            .having((s) => s.isLoadingLater, 'isLoadingLater', isTrue),
      );

      repository
        ..onQuery = null
        ..pending = null;
      fill.complete(Ok([withWalk]));
      await load;
      expect((cubit.state as TripResultsLoaded).journeys, [directS1, withWalk]);
    });

    test('stops at five trips', () async {
      repository.replies = [
        Ok([ride(10), ride(20), ride(30)]),
        Ok([ride(40), ride(50), ride(60)]),
      ];
      await cubit.load();

      expect((cubit.state as TripResultsLoaded).journeys, hasLength(6));
      expect(repository.queries, hasLength(2));
    });

    test('asks at most three more times', () async {
      var minute = 10;
      repository.replies = [
        Ok([ride(minute)]),
      ];
      repository.onQuery = () {
        minute += 10;
        repository.replies = [
          Ok([ride(minute)]),
        ];
      };
      await cubit.load();

      expect(repository.queries, hasLength(4));
      expect((cubit.state as TripResultsLoaded).journeys, hasLength(4));
    });

    group('outside NRW', () {
      late TripResultsCubit outside;

      setUp(() {
        repository.replies = [
          Ok([directS1]),
          Ok([withWalk]),
        ];
        outside = TripResultsCubit(
          repository,
          const TripQuery(from: berlinHbf, to: passauHbf, time: LeaveNow()),
          now: () => now,
        );
      });
      tearDown(() => outside.close());

      test('asks only once, as each request can take minutes', () async {
        await outside.load();
        expect(repository.queries, hasLength(1));
        expect((outside.state as TripResultsLoaded).journeys, [directS1]);
      });

      test('later trips can still be asked for', () async {
        await outside.load();
        await outside.loadLater();
        expect(repository.queries, hasLength(2));
        expect((outside.state as TripResultsLoaded).journeys, hasLength(2));
      });
    });

    test('a failure while filling up keeps the list quietly', () async {
      repository.replies = [
        Ok([directS1]),
        const Err(TimeoutFailure()),
      ];
      await cubit.load();

      expect(
        cubit.state,
        isA<TripResultsLoaded>()
            .having((s) => s.journeys, 'journeys', [directS1])
            .having((s) => s.laterFailure, 'laterFailure', isNull),
      );
    });

    test('later trips drop the ones that have left', () async {
      // withWalk leaves 07:21; directS1 left at 07:17.
      now = DateTime.utc(2026, 11, 2, 7, 19);
      await cubit.load();

      expect((cubit.state as TripResultsLoaded).journeys, [withWalk]);
    });

    test('failed later trips keep the list and report the failure', () async {
      repository.replies = [
        Ok([directS1]),
        // The automatic fill finds nothing new and stops.
        Ok([directS1]),
        const Err(TimeoutFailure()),
      ];
      await cubit.load();

      await cubit.loadLater();

      expect(
        cubit.state,
        isA<TripResultsLoaded>()
            .having((s) => s.journeys, 'journeys', [directS1])
            .having(
              (s) => s.laterFailure,
              'laterFailure',
              isA<TimeoutFailure>(),
            ),
      );
    });

    test('later trips run once at a time', () async {
      await cubit.load();
      final pending = repository.pending = Completer();

      final first = cubit.loadLater();
      final second = cubit.loadLater();
      pending.complete(Ok([laterRe11]));
      await Future.wait([first, second]);

      // The search, one automatic fill (nothing new), one later trips.
      expect(repository.queries, hasLength(3));
    });

    test('a cancelled request leaves the state to the newer one', () async {
      final pending = repository.pending = Completer();
      final load = cubit.load();

      pending.complete(const Err(CancelledFailure()));
      await load;

      expect(cubit.state, isA<TripResultsLoading>());
    });

    test('results after the page closed are ignored', () async {
      final pending = repository.pending = Completer<Result<List<Journey>>>();
      final load = cubit.load();
      await cubit.close();

      pending.complete(Ok([directS1]));
      await load;

      expect(cubit.state, isA<TripResultsLoading>());
    });
  });
}
