import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/reminders/data/reminder_repository_impl.dart';
import 'package:ruhr_transit/features/reminders/data/scheduled_reminder_alarms.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_worker.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_cubit.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_page.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fake_favourite_journeys_repository.dart';
import '../../helpers/fake_reminders.dart';
import '../../helpers/fake_vehicle_run_repository.dart';

DateTime _utc(int hour, int minute) => DateTime.utc(2026, 11, 4, hour, minute);

/// A walk of 10 minutes to the RE 6 at 08:30.
Journey _journey({String line = 'RE6'}) => Journey([
  WalkLeg(
    duration: const Duration(minutes: 10),
    origin: TripStop(name: 'Kortumstr. 10', plannedTime: _utc(8, 20)),
    destination: TripStop(name: 'Bochum Hbf', plannedTime: _utc(8, 30)),
  ),
  TransitLeg(
    line: line,
    mode: TransportMode.train,
    direction: 'Essen Hbf',
    origin: TripStop(
      name: 'Bochum Hbf',
      plannedTime: _utc(8, 30),
      platform: '3',
      position: const GeoPoint(51.4794, 7.2233),
    ),
    destination: TripStop(name: 'Essen Hbf', plannedTime: _utc(8, 45)),
    runKey: RunKey(
      lineId: 'ddb:90RE6: :H:j26',
      tripCode: '42',
      stopId: 'de:05911:5194:91:3',
      plannedDeparture: _utc(8, 30),
    ),
    originId: const StopRef('de:05911:5194:91:3', parentId: 'de:05911:5194'),
  ),
]);

Reminder _reminder({
  int id = 7,
  Duration lead = const Duration(minutes: 10),
  String languageCode = 'de',
}) => Reminder.forJourney(
  _journey(),
  id: id,
  lead: lead,
  languageCode: languageCode,
  use24HourFormat: true,
)!;

VehicleRun _run({required DateTime? estimated}) => VehicleRun([
  RunStop(
    id: 'de:05911:5194:91:3',
    parentId: 'de:05911:5194',
    name: 'Bochum Hbf',
    arrivalPlanned: _utc(8, 29),
    departurePlanned: _utc(8, 30),
    departureEstimated: estimated,
  ),
  RunStop(id: 'x', name: 'Essen Hbf', arrivalPlanned: _utc(8, 45)),
], isRealtime: estimated != null);

void main() {
  group('Reminder', () {
    test('counts back from the ride over the walk and the lead', () {
      final reminder = _reminder();

      expect(reminder.departure, _utc(8, 30));
      expect(reminder.walkBefore, const Duration(minutes: 10));
      expect(reminder.leaveAt, _utc(8, 20));
      expect(reminder.notifyAt, _utc(8, 10));
    });

    test('knows the station whose board its notification opens', () {
      final stop = _reminder().boardStop!;

      expect(stop.id, 'de:05911:5194');
      expect(stop.name, 'Bochum Hbf');
      expect(stop.latitude, 51.4794);
      expect(stop.kind, LocationKind.stop);
    });

    test('a walk alone has no ride to remind of', () {
      final walk = Journey([
        WalkLeg(
          duration: const Duration(minutes: 5),
          origin: TripStop(name: 'A', plannedTime: _utc(8, 0)),
          destination: TripStop(name: 'B', plannedTime: _utc(8, 5)),
        ),
      ]);

      expect(Reminder.keyOf(walk), isNull);
      expect(
        Reminder.forJourney(
          walk,
          id: 1,
          lead: const Duration(minutes: 5),
          languageCode: 'de',
          use24HourFormat: true,
        ),
        isNull,
      );
    });
  });

  group('ReminderRepositoryImpl', () {
    setUp(
      () => SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty(),
    );

    test('a broken optional field costs only that field', () async {
      final repository = ReminderRepositoryImpl(SharedPreferencesAsync());
      await repository.save([_reminder()]);
      final stored = await SharedPreferencesAsync().getString(
        ReminderRepositoryImpl.storageKey,
      );
      final entry = (jsonDecode(stored!) as List).single as Map;
      entry['platform'] = 3;
      await SharedPreferencesAsync().setString(
        ReminderRepositoryImpl.storageKey,
        jsonEncode([entry]),
      );

      final read = (await repository.load()).single;
      expect(read.id, 7);
      expect(read.platform, isNull);
    });

    test('keeps everything the alarm needs', () async {
      final repository = ReminderRepositoryImpl(SharedPreferencesAsync());
      await repository.save([_reminder()]);

      final read = (await repository.load()).single;

      expect(read.id, 7);
      expect(read.line, 'RE6');
      expect(read.mode, TransportMode.train);
      expect(read.platform, '3');
      expect(read.notifyAt, _utc(8, 10));
      expect(read.lead, const Duration(minutes: 10));
      expect(read.languageCode, 'de');
      expect(read.runKey?.lineId, 'ddb:90RE6: :H:j26');
      expect(read.runKey?.plannedDeparture, _utc(8, 30));
      expect(read.originParentId, 'de:05911:5194');
      expect(read.boardStop?.id, 'de:05911:5194');
    });

    test('reminders saved before the board stop existed still load', () async {
      final preferences = SharedPreferencesAsync();
      final repository = ReminderRepositoryImpl(preferences);
      await repository.save([_reminder()]);
      final saved = await preferences.getString(
        ReminderRepositoryImpl.storageKey,
      );
      final old =
          (jsonDecode(saved!) as List<Object?>).cast<Map<String, Object?>>()
            ..single.remove('boardStop');
      await preferences.setString(
        ReminderRepositoryImpl.storageKey,
        jsonEncode(old),
      );

      final read = (await repository.load()).single;

      expect(read.id, 7);
      expect(read.boardStop, isNull);
    });

    test(
      'unreadable data is no reminders, broken entries are skipped',
      () async {
        final preferences = SharedPreferencesAsync();
        final repository = ReminderRepositoryImpl(preferences);

        await preferences.setString(ReminderRepositoryImpl.storageKey, '{oops');
        expect(await repository.load(), isEmpty);

        await repository.save([_reminder()]);
        final good = await preferences.getString(
          ReminderRepositoryImpl.storageKey,
        );
        await preferences.setString(
          ReminderRepositoryImpl.storageKey,
          '[{"id":"x"},${good!.substring(1)}',
        );
        expect(await repository.load(), hasLength(1));
      },
    );
  });

  group('ReminderWorker', () {
    late FakeReminderRepository reminders;
    late FakeReminderAlarms alarms;
    late FakeReminderNotifier notifier;
    late FakeVehicleRunRepository runs;
    late DateTime now;

    setUp(() {
      reminders = FakeReminderRepository([_reminder()]);
      alarms = FakeReminderAlarms();
      notifier = FakeReminderNotifier();
      runs = FakeVehicleRunRepository();
      now = _utc(8, 10);
    });

    ReminderWorker worker() => ReminderWorker(
      reminders: reminders,
      alarms: alarms,
      notifier: notifier,
      runs: runs,
      now: () => now,
    );

    test('on time: notifies with the ride, and is done', () async {
      runs.reply = Ok(_run(estimated: _utc(8, 30)));

      await worker().fire(7);

      final shown = notifier.shown.single;
      expect(shown.id, 7);
      expect(shown.title, 'In 10 Min. losgehen');
      expect(notifier.openedBy.single?.stop?.id, 'de:05911:5194');
      expect(shown.body, contains('RE6 ab Bochum Hbf um'));
      expect(shown.body, contains('Gleis 3'));
      expect(shown.body, contains('10 Min. Fußweg'));
      expect(reminders.saved, isEmpty);
      expect(alarms.scheduled, isEmpty);
    });

    test('delayed: waits and checks again, then says how late', () async {
      runs.reply = Ok(_run(estimated: _utc(8, 42)));

      await worker().fire(7);

      expect(notifier.shown, isEmpty);
      expect(alarms.scheduled[7], (_utc(8, 22), true));
      expect(reminders.saved.single.departure, _utc(8, 42));

      now = _utc(8, 22);
      await worker().fire(7);

      expect(notifier.shown.single.body, contains('12 Min. später'));
      expect(reminders.saved, isEmpty);
    });

    test('a small delay does not move it', () async {
      runs.reply = Ok(_run(estimated: _utc(8, 31)));

      await worker().fire(7);

      expect(notifier.shown, hasLength(1));
      expect(alarms.scheduled, isEmpty);
    });

    test('offline, the reminder still comes with the known time', () async {
      runs.reply = const Err(NetworkFailure());

      await worker().fire(7);

      expect(notifier.shown.single.title, 'In 10 Min. losgehen');
      expect(reminders.saved, isEmpty);
    });

    test(
      'fired a moment after its time, it still says the full minutes',
      () async {
        runs.reply = Ok(_run(estimated: _utc(8, 30)));
        now = _utc(8, 10).add(const Duration(seconds: 3));

        await worker().fire(7);

        expect(notifier.shown.single.title, 'In 10 Min. losgehen');
      },
    );

    test('an alarm that comes late says how much time is left', () async {
      runs.reply = Ok(_run(estimated: _utc(8, 30)));
      now = _utc(8, 25);

      await worker().fire(7);

      expect(notifier.shown.single.title, 'Jetzt losgehen');
    });

    test('after the ride has left there is nothing to say', () async {
      runs.reply = const Err(NetworkFailure());
      now = _utc(9, 0);

      await worker().fire(7);

      expect(notifier.shown, isEmpty);
      expect(reminders.saved, isEmpty);
    });

    test('a removed reminder does nothing', () async {
      reminders.saved = [];

      await worker().fire(7);

      expect(notifier.shown, isEmpty);
      expect(runs.keys, isEmpty);
    });

    test('without exact alarms it waits inexactly', () async {
      notifier.exact = false;
      runs.reply = Ok(_run(estimated: _utc(8, 42)));

      await worker().fire(7);

      expect(alarms.scheduled[7], (_utc(8, 22), false));
    });

    test('writes in the language and clock format it was set in', () async {
      reminders.saved = [
        Reminder.forJourney(
          _journey(),
          id: 7,
          lead: const Duration(minutes: 10),
          languageCode: 'en',
          use24HourFormat: false,
        )!,
      ];
      runs.reply = Ok(_run(estimated: _utc(8, 30)));

      await worker().fire(7);

      expect(notifier.shown.single.title, 'Leave in 10 min');
      expect(notifier.shown.single.body, contains('RE6 from Bochum Hbf at'));
      expect(notifier.shown.single.body, matches(RegExp(r'\d:30 (AM|PM)')));
    });
  });

  group('ScheduledReminderAlarms (iOS)', () {
    late FakeReminderRepository reminders;
    late FakeReminderNotifier notifier;

    setUp(() {
      reminders = FakeReminderRepository([_reminder()]);
      notifier = FakeReminderNotifier();
    });

    ScheduledReminderAlarms alarms({DateTime? now}) => ScheduledReminderAlarms(
      reminders,
      notifier,
      now: () => now ?? _utc(7, 0),
    );

    test('schedules the notification itself, written for its time', () async {
      await alarms().schedule(7, _utc(8, 10), exact: false);

      final shown = notifier.shown.single;
      expect(shown.id, 7);
      expect(shown.title, 'In 10 Min. losgehen');
      expect(shown.body, contains('RE6 ab Bochum Hbf um'));
      expect(shown.body, contains('Gleis 3'));
      expect(notifier.shownAt.single, _utc(8, 10));
      expect(notifier.openedBy.single?.stop?.id, 'de:05911:5194');
    });

    test('a time that has passed schedules nothing', () async {
      await alarms(now: _utc(8, 10)).schedule(7, _utc(8, 10), exact: true);
      expect(notifier.shown, isEmpty);
    });

    test('an unknown reminder is an error', () async {
      expect(alarms().schedule(8, _utc(8, 10), exact: true), throwsStateError);
    });

    test('cancelling removes the scheduled notification', () async {
      await alarms().cancel(7);
      expect(notifier.cancelled, [7]);
    });

    test('with the cubit: a reminder schedules its notification', () async {
      reminders = FakeReminderRepository();
      final cubit = RemindersCubit(
        reminders,
        alarms(),
        notifier,
        now: () => _utc(7, 0),
      );
      await Future<void>.delayed(Duration.zero);

      final outcome = await cubit.add(
        _journey(),
        lead: const Duration(minutes: 10),
        languageCode: 'en',
        use24HourFormat: true,
      );

      expect(outcome, ReminderOutcome.set);
      expect(notifier.shownAt.single, _utc(8, 10));
      expect(notifier.shown.single.title, 'Leave in 10 min');
    });
  });

  test('reminderClock', () {
    final time = DateTime(2026, 11, 4, 0, 5);
    expect(reminderClock(time, true), '00:05');
    expect(reminderClock(time, false), '12:05 AM');
    expect(reminderClock(DateTime(2026, 11, 4, 20, 3), false), '8:03 PM');
  });

  group('RemindersCubit', () {
    late FakeReminderRepository reminders;
    late FakeReminderAlarms alarms;
    late FakeReminderNotifier notifier;

    setUp(() {
      reminders = FakeReminderRepository();
      alarms = FakeReminderAlarms();
      notifier = FakeReminderNotifier();
    });

    RemindersCubit cubit({DateTime? at}) => RemindersCubit(
      reminders,
      alarms,
      notifier,
      now: () => at ?? _utc(7, 0),
    );

    Future<ReminderOutcome> add(RemindersCubit cubit, {int minutes = 10}) =>
        cubit.add(
          _journey(),
          lead: Duration(minutes: minutes),
          languageCode: 'de',
          use24HourFormat: true,
        );

    test('sets the alarm, saves it and finds it for the journey', () async {
      final reminders0 = cubit();
      await Future<void>.delayed(Duration.zero);

      expect(await add(reminders0), ReminderOutcome.set);

      final reminder = reminders.saved.single;
      expect(alarms.scheduled[reminder.id], (_utc(8, 10), true));
      expect(reminders0.reminderFor(_journey()), isNotNull);
      expect(reminders0.reminderFor(_journey(line: 'S1')), isNull);
    });

    test('refused notifications set nothing', () async {
      notifier.permission = false;
      final reminders0 = cubit();
      await Future<void>.delayed(Duration.zero);

      expect(await add(reminders0), ReminderOutcome.denied);
      expect(reminders.saved, isEmpty);
      expect(alarms.scheduled, isEmpty);
    });

    test('says when it may come late', () async {
      notifier.exact = false;
      final reminders0 = cubit();
      await Future<void>.delayed(Duration.zero);

      expect(await add(reminders0), ReminderOutcome.setInexact);
      expect(alarms.scheduled.values.single.$2, isFalse);
    });

    test('too late, or the alarm fails: nothing stays', () async {
      final late = cubit(at: _utc(8, 15));
      await Future<void>.delayed(Duration.zero);
      expect(await add(late), ReminderOutcome.tooLate);

      alarms.error = StateError('no');
      final failing = cubit();
      await Future<void>.delayed(Duration.zero);
      expect(await add(failing), ReminderOutcome.failed);
      expect(reminders.saved, isEmpty);
      expect(failing.state, isEmpty);
    });

    test('a second reminder for a journey replaces the first', () async {
      final reminders0 = cubit();
      await Future<void>.delayed(Duration.zero);
      await add(reminders0);
      final first = reminders.saved.single.id;
      await Future<void>.delayed(const Duration(milliseconds: 1));

      await add(reminders0, minutes: 30);

      expect(reminders.saved, hasLength(1));
      expect(reminders.saved.single.lead, const Duration(minutes: 30));
      expect(alarms.cancelled, [first]);
    });

    test('offers only what still lies ahead', () async {
      final reminders0 = cubit(at: _utc(8, 8));
      await Future<void>.delayed(Duration.zero);

      expect(reminders0.leadsFor(_journey()), const [
        Duration(minutes: 5),
        Duration(minutes: 10),
      ]);
    });

    test('removing cancels alarm and notification', () async {
      final reminders0 = cubit();
      await Future<void>.delayed(Duration.zero);
      await add(reminders0);
      final reminder = reminders0.state.single;

      await reminders0.remove(reminder);

      expect(alarms.cancelled, [reminder.id]);
      expect(notifier.cancelled, [reminder.id]);
      expect(reminders.saved, isEmpty);
      expect(reminders0.state, isEmpty);
    });

    test('on start: sets alarms again, forgets rides that have left', () async {
      reminders.saved = [_reminder()];
      final reminders0 = cubit();
      await Future<void>.delayed(Duration.zero);
      expect(alarms.scheduled[7], (_utc(8, 10), true));
      await reminders0.close();

      reminders.saved = [_reminder()];
      alarms.scheduled.clear();
      final later = cubit(at: _utc(9, 0));
      await Future<void>.delayed(Duration.zero);
      expect(later.state, isEmpty);
      expect(reminders.saved, isEmpty);
      expect(alarms.scheduled, isEmpty);
    });
  });

  group('screens', () {
    late FakeReminderRepository reminders;
    late FakeReminderAlarms alarms;
    late FakeReminderNotifier notifier;

    setUp(() {
      reminders = FakeReminderRepository();
      alarms = FakeReminderAlarms();
      notifier = FakeReminderNotifier();
    });

    Widget app(Widget home, {DateTime? at}) => MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
        ),
        BlocProvider(
          create: (_) => RemindersCubit(
            reminders,
            alarms,
            notifier,
            now: () => at ?? _utc(7, 0),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

    testWidgets('trip details set and remove a reminder', (tester) async {
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: _journey(), runs: null)),
      );
      await tester.pump();

      await tester.tap(find.text('Remind me to leave'));
      await tester.pumpAndSettle();
      expect(find.text('When should the reminder come?'), findsOneWidget);
      expect(find.text('30 min before leaving'), findsOneWidget);

      await tester.tap(find.text('10 min before leaving'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Reminder at'), findsOneWidget);
      expect(find.textContaining('Reminder set.'), findsOneWidget);
      expect(reminders.saved.single.lead, const Duration(minutes: 10));

      await tester.tap(find.byTooltip('Remove reminder'));
      await tester.pumpAndSettle();
      expect(find.text('Remind me to leave'), findsOneWidget);
      expect(reminders.saved, isEmpty);
    });

    testWidgets('refused notifications say so, with the way to settings', (
      tester,
    ) async {
      notifier.permission = false;
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: _journey(), runs: null)),
      );
      await tester.pump();

      await tester.tap(find.text('Remind me to leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 min before leaving'));
      await tester.pumpAndSettle();

      expect(find.textContaining('allowed to send notifications'), findsOne);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('inexact alarms offer the setting', (tester) async {
      notifier.exact = false;
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: _journey(), runs: null)),
      );
      await tester.pump();

      await tester.tap(find.text('Remind me to leave'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 min before leaving'));
      await tester.pumpAndSettle();

      expect(find.textContaining('a few minutes late'), findsOneWidget);
      await tester.tap(find.text('On time'));
      expect(notifier.exactRequests, 1);
    });

    testWidgets('no offer when it is too late', (tester) async {
      await tester.pumpWidget(
        app(
          JourneyDetailsPage(journey: _journey(), runs: null),
          at: _utc(8, 19),
        ),
      );
      await tester.pump();

      expect(find.text('Remind me to leave'), findsNothing);
    });

    testWidgets('the list removes reminders, and says when there are none', (
      tester,
    ) async {
      reminders.saved = [_reminder()];
      await tester.pumpWidget(app(const RemindersPage()));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('RE6 from Bochum Hbf at'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove reminder'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('No reminders set'), findsOneWidget);
    });
  });
}
