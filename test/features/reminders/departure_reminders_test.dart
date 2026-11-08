import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/departures/data/departure_mapper.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/home/presentation/home_shell.dart';
import 'package:ruhr_transit/features/language/presentation/locale_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/recent_stops/presentation/recent_stops_cubit.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_cubit.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/weather/domain/weather_repository.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

import '../../helpers/fake_departure_repository.dart';
import '../../helpers/fake_favourite_journeys_repository.dart';
import '../../helpers/fake_favourites_repository.dart';
import '../../helpers/fake_nearby_stops.dart';
import '../../helpers/fake_recent_stops_repository.dart';
import '../../helpers/fake_reminders.dart';
import '../../helpers/fake_settings.dart';
import '../../helpers/fake_stop_repository.dart';
import '../../helpers/fake_trip_repository.dart';
import '../../helpers/fake_vehicle_run_repository.dart';
import '../../helpers/fake_weather_repository.dart';
import '../../helpers/fake_widget_sync.dart';
import '../../helpers/fixtures.dart';

void main() {
  group('departures from VRR', () {
    test('carry what the delay check needs', () {
      final departures = mapDepartureMonitorResponse(
        readEfaFixtureJson('dm_bochum_hbf'),
      );

      final re16 = departures.first;
      expect(re16.runKey?.lineId, 'ddb:90E16: :R:j26');
      expect(re16.runKey?.tripCode, '242');
      expect(re16.runKey?.stopId, 'de:05911:5194:91:3');
      expect(re16.runKey?.plannedDeparture, re16.plannedTime);
    });
  });

  group('a reminder for one departure', () {
    final departure = Departure(
      line: 'RE16',
      mode: TransportMode.train,
      destination: 'Essen',
      plannedTime: DateTime.utc(2026, 11, 6, 8, 30),
      estimatedTime: DateTime.utc(2026, 11, 6, 8, 33),
      platform: '3',
    );

    test('counts back from the live time, with nothing to walk', () {
      final reminder = Reminder.forDeparture(
        departure,
        bochumHbf,
        id: 1,
        lead: const Duration(minutes: 10),
        languageCode: 'de',
        use24HourFormat: true,
      );

      expect(reminder.notifyAt, DateTime.utc(2026, 11, 6, 8, 23));
      expect(reminder.walkBefore, Duration.zero);
      expect(reminder.stopName, 'Bochum, Hbf');
      expect(reminder.opening.stop, bochumHbf);
      expect(reminder.opening.from, isNull);
    });
  });

  group('departure board', () {
    late FakeReminderRepository reminders;
    late FakeReminderAlarms alarms;
    late FakeDepartureRepository departures;

    setUp(() {
      reminders = FakeReminderRepository();
      alarms = FakeReminderAlarms();
      departures = FakeDepartureRepository()..autoReply = Ok([delayedRe16]);
    });

    Future<void> pump(WidgetTester tester, {DateTime? at}) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => FavouritesCubit(FakeFavouritesRepository()),
            ),
            BlocProvider(
              create: (_) => RemindersCubit(
                reminders,
                alarms,
                FakeReminderNotifier(),
                now: () => at ?? boardTime,
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider(
              create: (_) => DeparturesCubit(
                departures,
                bochumHbf.id,
                now: () => boardTime,
              )..load(),
              child: DeparturesView(
                stop: bochumHbf,
                widgetSync: FakeWidgetSync(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a tap sets a reminder, and shows it on the row', (
      tester,
    ) async {
      final minutes = delayedRe16.time.difference(boardTime).inMinutes;
      expect(minutes, greaterThan(5));
      await pump(tester);

      await tester.tap(
        find.textContaining(delayedRe16.line, findRichText: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('5 min before it leaves'), findsOneWidget);

      await tester.tap(find.text('5 min before it leaves'));
      await tester.pumpAndSettle();

      expect(reminders.saved.single.lead, const Duration(minutes: 5));
      expect(find.byIcon(Icons.notifications_active), findsOneWidget);
    });

    testWidgets('a second tap can remove it', (tester) async {
      await pump(tester);
      await tester.tap(
        find.textContaining(delayedRe16.line, findRichText: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 min before it leaves'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await tester.tap(
        find.textContaining(delayedRe16.line, findRichText: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove reminder'));
      await tester.pumpAndSettle();

      expect(reminders.saved, isEmpty);
      expect(find.byIcon(Icons.notifications_active), findsNothing);
    });

    testWidgets('nothing to offer once it is too late', (tester) async {
      await pump(tester, at: delayedRe16.time);

      await tester.tap(
        find.textContaining(delayedRe16.line, findRichText: true),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('before it leaves'), findsNothing);
    });

    testWidgets('a cancelled departure offers nothing', (tester) async {
      departures.autoReply = Ok([cancelledRe11]);
      await pump(tester);

      await tester.tap(
        find.textContaining(cancelledRe11.line, findRichText: true),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('before it leaves'), findsNothing);
    });

    testWidgets('TalkBack can tap it and hears that a reminder is set', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      await tester.tap(
        find.textContaining(delayedRe16.line, findRichText: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('5 min before it leaves'));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'Reminder set$')), findsOneWidget);
      semantics.dispose();
    });
  });

  group('tapping a notification', () {
    late FakeTripRepository trips;

    setUp(() {
      trips = FakeTripRepository();
      getIt
        ..registerFactory<StopRepository>(FakeStopRepository.new)
        ..registerSingleton<LocationSource>(FakeLocationSource())
        ..registerFactory<TripRepository>(() => trips)
        ..registerFactory<WeatherRepository>(FakeWeatherRepository.new)
        ..registerFactory<VehicleRunRepository>(FakeVehicleRunRepository.new)
        ..registerFactory<DepartureRepository>(
          () => FakeDepartureRepository()..autoReply = const Ok([]),
        )
        ..registerSingleton<WidgetSync>(FakeWidgetSync());
    });
    tearDown(getIt.reset);

    Future<HomeShellState> pumpShell(WidgetTester tester) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => FavouritesCubit(FakeFavouritesRepository()),
            ),
            BlocProvider(
              create: (_) =>
                  FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
            ),
            BlocProvider(create: (_) => LocaleCubit(FakeLanguageRepository())),
            BlocProvider(create: (_) => ThemeCubit(FakeThemeRepository())),
            BlocProvider(
              create: (_) => RecentStopsCubit(FakeRecentStopsRepository()),
            ),
            BlocProvider(
              create: (_) =>
                  ProfileCubit(FakeProfileRepository(), FakeAuthRepository()),
            ),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HomeShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.state<HomeShellState>(find.byType(HomeShell));
    }

    ReminderOpening openingOf(String? key) => ReminderOpening(
      key: key ?? 'no such trip',
      searchFrom: DateTime.utc(2026, 11, 2, 7),
      stop: bochumHbf,
      from: bochumHbf,
      to: dortmundHbf,
    );

    testWidgets('finds the trip again and opens it', (tester) async {
      final shell = await pumpShell(tester);

      await shell.openReminder(openingOf(Reminder.keyOf(withWalk)));
      await tester.pumpAndSettle();

      final page = tester.widget<JourneyDetailsPage>(
        find.byType(JourneyDetailsPage),
      );
      expect(page.journey, same(withWalk));
      expect(page.query?.from, bochumHbf);
      final asked = trips.queries.single;
      expect(asked.to, dortmundHbf);
      expect(
        asked.time,
        isA<DepartAt>().having(
          (t) => t.time,
          'time',
          DateTime.utc(2026, 11, 2, 7).toLocal(),
        ),
      );
    });

    testWidgets('trip gone, or offline: the stop instead', (tester) async {
      final shell = await pumpShell(tester);

      await shell.openReminder(openingOf(null));
      await tester.pumpAndSettle();
      expect(find.byType(JourneyDetailsPage), findsNothing);
      expect(find.byType(DeparturesPage), findsOneWidget);
      expect(find.text('Bochum, Hbf'), findsOneWidget);
    });

    testWidgets('offline: the stop too', (tester) async {
      trips.replies = [const Err(NetworkFailure())];
      final shell = await pumpShell(tester);

      await shell.openReminder(openingOf(Reminder.keyOf(withWalk)));
      await tester.pumpAndSettle();

      expect(find.byType(DeparturesPage), findsOneWidget);
    });
  });

  group('next departures on nearby stops', () {
    Future<void> pump(
      WidgetTester tester, {
      required FakeDepartureRepository Function() departures,
      List<NearbyStop> stops = nearbyStops,
    }) async {
      await tester.pumpWidget(
        BlocProvider(
          create: (_) => FavouritesCubit(FakeFavouritesRepository()),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider(
              create: (_) => NearbyStopsCubit(
                FakeLocationSource()..permissionGranted = true,
                FakeNearbyStopsRepository()..reply = Ok(stops),
              )..load(),
              child: NearbyStopsView(departures: departures),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
    }

    Departure leaving(String line, Duration from, {bool cancelled = false}) =>
        Departure(
          line: line,
          destination: 'Somewhere',
          plannedTime: DateTime.now().toUtc().add(from),
          isCancelled: cancelled,
        );

    testWidgets('shows the next two, skipping cancelled and departed', (
      tester,
    ) async {
      await pump(
        tester,
        departures: () => FakeDepartureRepository()
          ..autoReply = Ok([
            leaving('OLD', const Duration(minutes: -5)),
            leaving('X', const Duration(minutes: 2), cancelled: true),
            leaving('365', const Duration(seconds: 20)),
            leaving('355', const Duration(minutes: 14, seconds: 30)),
            leaving('LATER', const Duration(minutes: 30)),
          ]),
      );

      expect(find.text('365 now · 355 in 14 min'), findsNWidgets(2));
    });

    testWidgets('asks for the closest three stops only', (tester) async {
      final asked = <String>[];
      final stops = [
        for (var i = 0; i < 5; i++)
          NearbyStop(
            Stop(
              id: 'stop$i',
              name: 'Stop $i',
              fullName: 'Bochum, Stop $i',
              locality: 'Bochum',
              latitude: 51.48,
              longitude: 7.22,
              modes: const {TransportMode.bus},
            ),
            distanceMeters: i * 100,
          ),
      ];
      await pump(
        tester,
        stops: stops,
        departures: () {
          final repository = FakeDepartureRepository()
            ..autoReply = const Ok([]);
          asked.add('made');
          return repository;
        },
      );

      expect(asked, hasLength(3));
    });

    testWidgets('a failed request leaves the row as it was', (tester) async {
      await pump(
        tester,
        departures: () =>
            FakeDepartureRepository()..autoReply = const Err(NetworkFailure()),
      );

      expect(find.text('Bochum · 40 m away'), findsOneWidget);
      expect(find.textContaining(' in '), findsNothing);
    });
  });
}
