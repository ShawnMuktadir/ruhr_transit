import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/map/base_map.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/home/presentation/favourites_tab.dart';
import 'package:ruhr_transit/features/home/presentation/home_shell.dart';
import 'package:ruhr_transit/features/language/presentation/locale_cubit.dart';
import 'package:ruhr_transit/features/legal/presentation/legal_page.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/onboarding/presentation/onboarding_cubit.dart';
import 'package:ruhr_transit/features/onboarding/presentation/onboarding_page.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_page.dart';
import 'package:ruhr_transit/features/recent_stops/presentation/recent_stops_cubit.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_cubit.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_page.dart';
import 'package:ruhr_transit/features/settings/presentation/settings_page.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/domain/current_location_finder.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/walk_to_stop.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/stop_actions.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_map_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';
import 'package:ruhr_transit/features/weather/domain/weather_repository.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_cubit.dart';

import '../helpers/fake_departure_repository.dart';
import '../helpers/fake_favourite_journeys_repository.dart';
import '../helpers/fake_favourites_repository.dart';
import '../helpers/fake_nearby_stops.dart';
import '../helpers/fake_recent_stops_repository.dart';
import '../helpers/fake_reminders.dart';
import '../helpers/fake_settings.dart';
import '../helpers/fake_stop_repository.dart';
import '../helpers/fake_trip_repository.dart';
import '../helpers/fake_vehicle_run_repository.dart';
import '../helpers/fake_weather_repository.dart';
import '../helpers/fake_widget_sync.dart';
import '../helpers/fixtures.dart';

/// Every screen, in light and dark, at 100, 130 and 200 % font size, on a
/// phone-sized screen: no layout overflow (an overflow fails the test by
/// itself), and Android's tap target, label and contrast guidelines.
void main() {
  // The disk cache needs a plugin that does not run in tests.
  setUpAll(
    () => BaseMap.tileProvider = () => NetworkTileProvider(
      cachingProvider: const DisabledMapCachingProvider(),
    ),
  );

  // The home screen's planner makes its weather chip through get_it.
  setUp(
    () => getIt
      ..registerSingleton<LocationSource>(
        FakeLocationSource()..permissionGranted = true,
      )
      ..registerFactory<WeatherRepository>(FakeWeatherRepository.new)
      ..registerFactory<StopRepository>(FakeStopRepository.new),
  );
  tearDown(getIt.reset);

  /// [page] with reminders, at a time before the sample journey leaves.
  Widget reminders(
    Widget page, {
    List<Reminder> saved = const [],
    DateTime? at,
  }) => BlocProvider(
    create: (_) => RemindersCubit(
      FakeReminderRepository(saved),
      FakeReminderAlarms(),
      FakeReminderNotifier(),
      now: () => at ?? DateTime.utc(2026, 11, 2, 6),
    ),
    child: page,
  );

  Reminder reminderForS1() => Reminder.forJourney(
    directS1,
    id: 1,
    lead: const Duration(minutes: 10),
    languageCode: 'de',
    use24HourFormat: true,
  )!;

  Widget tripWithWay() => TripActions(
    planFrom: (_) {},
    walkToStop: () => WalkToStop(
      CurrentLocationFinder(FakeLocationSource(), FakeStopRepository()),
      FakeTripRepository()
        ..walkReply = Ok(
          mapTripResponse(readEfaFixtureJson('trip_walk_only')).first,
        ),
    ),
    child: JourneyDetailsPage(
      journey: mapTripResponse(
        readEfaFixtureJson('trip_bochum_dortmund'),
      ).first,
      runs: null,
    ),
  );

  Widget nearby() => BlocProvider(
    create: (_) => NearbyStopsCubit(
      FakeLocationSource()..permissionGranted = true,
      FakeNearbyStopsRepository(),
    )..load(),
    child: const NearbyStopsView(),
  );

  Widget planner(WeatherCubit weather) => BlocProvider(
    create: (_) => TripFormCubit(),
    child: BlocProvider(
      create: (_) => weather..load(),
      child: const TripFormView(showWeather: true),
    ),
  );

  Widget onboarding() => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => LocaleCubit(FakeLanguageRepository())),
      BlocProvider(
        create: (_) =>
            OnboardingCubit(FakeOnboardingRepository(), completed: false),
      ),
    ],
    child: const OnboardingPage(),
  );

  Widget favouritesTab(FavouritesSegment segment) => FavouritesTab(
    segment: ValueNotifier(segment),
    onOpenJourney: (_) {},
    stops: BlocProvider(
      create: (_) => StopSearchCubit(FakeStopRepository()),
      child: const StopSearchBody(),
    ),
  );

  Widget settings(Widget page) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => LocaleCubit(FakeLanguageRepository())),
      BlocProvider(create: (_) => ThemeCubit(FakeThemeRepository())),
      BlocProvider(
        create: (_) =>
            ProfileCubit(FakeProfileRepository('Kim'), FakeAuthRepository()),
      ),
    ],
    child: page,
  );

  final screens = <String, Widget Function()>{
    // The text on the sky, for every kind of weather.
    for (final sky in WeatherSky.values)
      'trip form, ${sky.name}': () => planner(
        WeatherCubit(
          FakeWeatherRepository(Ok(cloudyWithRain.withSky(sky))),
          FakeLocationSource()..permissionGranted = true,
        ),
      ),
    'welcome': onboarding,
    'language choice': onboarding,
    'start screen without favourites': () => BlocProvider(
      create: (_) => StopSearchCubit(FakeStopRepository()),
      child: const StopSearchView(),
    ),
    'stop picker with favourites and history': () => BlocProvider(
      create: (_) => StopSearchCubit(FakeStopRepository()),
      child: StopSearchView(title: 'Start wählen', onPicked: (_) {}),
    ),
    'start screen with favourites': () => BlocProvider(
      create: (_) => StopSearchCubit(FakeStopRepository()),
      child: const StopSearchView(),
    ),
    'departure board with Plan trip from here': () => TripActions(
      planFrom: (_) {},
      walkToStop: () => throw StateError('Not tapped here'),
      child: BlocProvider(
        create: (_) => DeparturesCubit(
          FakeDepartureRepository()
            ..autoReply = Ok([delayedRe16, cancelledRe11, movedU35]),
          bochumHbf.id,
          now: () => boardTime,
        )..load(),
        child: DeparturesView(stop: bochumHbf, widgetSync: FakeWidgetSync()),
      ),
    ),
    'trip details, way to the first stop offered': tripWithWay,
    'trip details, way to the first stop added': tripWithWay,
    'nearby stops with their next departures': () => BlocProvider(
      create: (_) => NearbyStopsCubit(
        FakeLocationSource()..permissionGranted = true,
        FakeNearbyStopsRepository(),
      )..load(),
      child: NearbyStopsView(
        departures: () => FakeDepartureRepository()
          ..autoReply = Ok([
            Departure(
              line: '365',
              destination: 'Bochum Hbf',
              plannedTime: DateTime.now().toUtc().add(
                const Duration(minutes: 9),
              ),
            ),
          ]),
      ),
    ),
    'departure board, reminder options': () => reminders(
      BlocProvider(
        create: (_) => DeparturesCubit(
          FakeDepartureRepository()..autoReply = Ok([delayedRe16]),
          bochumHbf.id,
          now: () => boardTime,
        )..load(),
        child: DeparturesView(stop: bochumHbf, widgetSync: FakeWidgetSync()),
      ),
      at: delayedRe16.plannedTime.subtract(const Duration(minutes: 40)),
    ),
    'nearby stops, stars and filter chips': nearby,
    'nearby stops, on the map': nearby,
    'nearby stops, a pin chosen on the map': () => TripActions(
      planFrom: (_) {},
      walkToStop: () => throw StateError('Not tapped here'),
      child: nearby(),
    ),
    'trip on the map': () => TripMapPage(
      journey: mapTripResponse(readEfaFixtureJson('trip_with_walk')).first,
    ),
    'trip details, reminder offered': () =>
        reminders(JourneyDetailsPage(journey: directS1, runs: null)),
    'trip details, choosing a reminder': () =>
        reminders(JourneyDetailsPage(journey: directS1, runs: null)),
    'trip details, reminder set': () => reminders(
      JourneyDetailsPage(journey: directS1, runs: null),
      saved: [reminderForS1()],
    ),
    'reminders, none': () => reminders(const RemindersPage()),
    'reminders, one set': () =>
        reminders(const RemindersPage(), saved: [reminderForS1()]),
    'departure board': () => BlocProvider(
      create: (_) => DeparturesCubit(
        FakeDepartureRepository()
          ..autoReply = Ok([delayedRe16, cancelledRe11, movedU35]),
        bochumHbf.id,
        now: () => boardTime,
      )..load(),
      child: DeparturesView(stop: bochumHbf, widgetSync: FakeWidgetSync()),
    ),
    'outdated departure board': () => BlocProvider(
      create: (_) => DeparturesCubit(
        FakeDepartureRepository()
          ..autoReply = const Err(NetworkFailure())
          ..savedBoard = DepartureBoard([
            delayedRe16,
            movedU35,
          ], fetchedAt: boardTime),
        bochumHbf.id,
        now: () => boardTime,
      )..load(),
      child: DeparturesView(stop: bochumHbf, widgetSync: FakeWidgetSync()),
    ),
    'nearby stops, approximate': () => BlocProvider(
      create: (_) => NearbyStopsCubit(
        FakeLocationSource()
          ..result = const Located(
            latitude: 51.4,
            longitude: 7.2,
            isApproximate: true,
          ),
        FakeNearbyStopsRepository(),
      )..load(),
      child: const NearbyStopsView(),
    ),
    'nearby stops, permission denied for good': () => BlocProvider(
      create: (_) => NearbyStopsCubit(
        FakeLocationSource()
          ..result = const LocationPermissionDenied(permanently: true),
        FakeNearbyStopsRepository(),
      )..load(),
      child: const NearbyStopsView(),
    ),
    'trip form': () => BlocProvider(
      create: (_) => TripFormCubit()
        ..setFrom(bochumHbf)
        ..setTo(dortmundHbf)
        ..arriveBy(DateTime(2026, 11, 2, 18, 30)),
      child: const TripFormView(),
    ),
    'trip form with the weather': () => planner(
      WeatherCubit(
        FakeWeatherRepository(),
        FakeLocationSource()..permissionGranted = true,
      ),
    ),
    'trip form, weather needs location': () =>
        planner(WeatherCubit(FakeWeatherRepository(), FakeLocationSource())),
    'trip results, waiting outside NRW': () {
      const query = TripQuery(from: berlinHbf, to: passauHbf, time: LeaveNow());
      return BlocProvider(
        create: (_) =>
            TripResultsCubit(FakeTripRepository()..pending = Completer(), query)
              ..load(),
        child: const TripResultsView(query: query),
      );
    },
    'trip results, no answer outside NRW': () {
      const query = TripQuery(from: berlinHbf, to: passauHbf, time: LeaveNow());
      return BlocProvider(
        create: (_) => TripResultsCubit(
          FakeTripRepository()..replies = [const Err(OutsideNrwFailure())],
          query,
        )..load(),
        child: const TripResultsView(query: query),
      );
    },
    'trip results': () => BlocProvider(
      create: (_) => TripResultsCubit(
        FakeTripRepository(),
        const TripQuery(from: bochumHbf, to: dortmundHbf, time: LeaveNow()),
        now: () => DateTime.utc(2026, 11, 2, 7),
      )..load(),
      child: const TripResultsView(
        query: TripQuery(from: bochumHbf, to: dortmundHbf, time: LeaveNow()),
      ),
    ),
    // The U35 between Lennershof and Ruhr-Universität, where the user
    // boards: the stops before are open, with the vehicle marker.
    'journey details': () => JourneyDetailsPage(
      journey: withWalk,
      query: const TripQuery(
        from: bochumHbf,
        to: dortmundHbf,
        time: LeaveNow(),
      ),
      runs: FakeVehicleRunRepository.new,
      now: () => DateTime.utc(2026, 11, 2, 7, 20),
    ),
    'journey details, run unavailable': () =>
        JourneyDetailsPage(journey: withWalk, runs: null),
    'journey details, everything open': () => JourneyDetailsPage(
      journey: withWalk,
      runs: FakeVehicleRunRepository.new,
      now: () => DateTime.utc(2026, 11, 2, 7, 20),
    ),
    'notice text': () => JourneyDetailsPage(journey: withWalk, runs: null),
    'nearby stops, before asking': () => BlocProvider(
      create: (_) =>
          NearbyStopsCubit(FakeLocationSource(), FakeNearbyStopsRepository())
            ..start(),
      child: const NearbyStopsView(),
    ),
    'favourites, no saved journeys': () =>
        favouritesTab(FavouritesSegment.journeys),
    'favourites, saved journeys': () =>
        favouritesTab(FavouritesSegment.journeys),
    'favourites, stops': () => favouritesTab(FavouritesSegment.stops),
    'settings': () =>
        settings(const SettingsPage(packageInfo: fakePackageInfo)),
    'profile': () => settings(const ProfilePage()),
    'privacy policy': () => const LegalPage(LegalDocument.privacy),
    'terms and conditions': () => const LegalPage(LegalDocument.terms),
    'home with navigation bar': () => BlocProvider(
      create: (_) => LocaleCubit(FakeLanguageRepository()),
      child: const HomeShell(),
    ),
  };

  /// Steps to reach a screen that has no page of its own.
  final reach = <String, Future<void> Function(WidgetTester)>{
    'trip details, way to the first stop added': (tester) async {
      await tester.tap(find.textContaining('Weg zu'));
      await tester.pumpAndSettle();
    },
    'departure board, reminder options': (tester) async {
      await tester.tap(
        find.textContaining(delayedRe16.line, findRichText: true),
      );
      await tester.pumpAndSettle();
    },
    'nearby stops, on the map': (tester) async {
      await tester.tap(find.text('Karte'));
      await tester.pump();
      await tester.pump();
    },
    'nearby stops, a pin chosen on the map': (tester) async {
      await tester.tap(find.text('Karte'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.location_on).first);
      await tester.pump();
    },
    'trip details, choosing a reminder': (tester) async {
      await tester.tap(find.text('Ans Losgehen erinnern'));
      await tester.pumpAndSettle();
    },
    'language choice': (tester) async {
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    },
    'journey details, run unavailable': (tester) async {
      // At 2x the row is further down than the list has built yet.
      await tester.scrollUntilVisible(
        find.textContaining('Zwischenhalte'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('Zwischenhalte'));
      await tester.tap(find.textContaining('Zwischenhalte'));
      await tester.pumpAndSettle();
    },
    'journey details, everything open': (tester) async {
      await tester.tap(find.textContaining('Hinweise'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Halt danach'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.textContaining('Halt danach'));
      await tester.tap(find.textContaining('Halt danach'));
      await tester.pumpAndSettle();
    },
    'notice text': (tester) async {
      await tester.tap(find.textContaining('Hinweise'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(lineNotice.title));
      await tester.tap(find.text(lineNotice.title));
      await tester.pumpAndSettle();
    },
  };

  for (final MapEntry(key: name, value: build) in screens.entries) {
    for (final brightness in Brightness.values) {
      for (final textScale in [1.0, 1.3, 2.0]) {
        testWidgets('$name, ${brightness.name}, text ×$textScale', (
          tester,
        ) async {
          tester.view
            ..physicalSize = const Size(1080, 2400)
            ..devicePixelRatio = 2.625;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          final favourites = FakeFavouritesRepository(
            name.contains('with favourites') ? [bochumHbf, dortmundHbf] : [],
          );
          // The picker test shows Dortmund as a favourite only.
          if (name.contains('history')) favourites.saved = [dortmundHbf];

          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      FavouritesCubit(favourites, initial: favourites.saved),
                ),
                BlocProvider(
                  create: (_) => RecentStopsCubit(
                    FakeRecentStopsRepository(),
                    initial: name.contains('history')
                        ? [
                            bochumHbf,
                            const Stop(
                              id: 'de:05913:131',
                              name: 'Hbf',
                              fullName: 'Dortmund, Hbf',
                              locality: 'Dortmund',
                              latitude: 51.5,
                              longitude: 7.4,
                            ),
                          ]
                        : const [],
                  ),
                ),
                BlocProvider(
                  create: (_) => FavouriteJourneysCubit(
                    FakeFavouriteJourneysRepository([
                      if (name.contains('saved journeys') &&
                          !name.contains('no saved')) ...[
                        FavouriteJourney(
                          from: bochumHbf,
                          to: dortmundHbf,
                          savedAt: DateTime.utc(2026, 11, 2),
                          label: 'Work, RE1 at 7:40',
                        ),
                        FavouriteJourney(
                          from: dortmundHbf,
                          to: bochumHbf,
                          savedAt: DateTime.utc(2026, 11, 2),
                        ),
                      ],
                    ]),
                  ),
                ),
                // The planner greets with the profile's name.
                BlocProvider(
                  create: (_) => ProfileCubit(
                    FakeProfileRepository('Shawn'),
                    FakeAuthRepository(),
                  ),
                ),
              ],
              child: MaterialApp(
                locale: const Locale('de'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(textScale),
                    // A still picture, as the sky's movement never settles.
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: build(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await reach[name]?.call(tester);

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        });
      }
    }
  }
}
