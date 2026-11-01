import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';
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
import 'package:ruhr_transit/features/settings/presentation/settings_page.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

import '../helpers/fake_departure_repository.dart';
import '../helpers/fake_favourite_journeys_repository.dart';
import '../helpers/fake_favourites_repository.dart';
import '../helpers/fake_nearby_stops.dart';
import '../helpers/fake_settings.dart';
import '../helpers/fake_stop_repository.dart';
import '../helpers/fake_trip_repository.dart';
import '../helpers/fake_widget_sync.dart';

/// Every screen, in light and dark, at 100, 130 and 200 % font size, on a
/// phone-sized screen: no layout overflow (an overflow fails the test by
/// itself), and Android's tap target, label and contrast guidelines.
void main() {
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
    'welcome': onboarding,
    'language choice': onboarding,
    'start screen without favourites': () => BlocProvider(
      create: (_) => StopSearchCubit(FakeStopRepository()),
      child: const StopSearchView(),
    ),
    'start screen with favourites': () => BlocProvider(
      create: (_) => StopSearchCubit(FakeStopRepository()),
      child: const StopSearchView(),
    ),
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
    'journey details': () => JourneyDetailsPage(
      journey: withWalk,
      query: const TripQuery(
        from: bochumHbf,
        to: dortmundHbf,
        time: LeaveNow(),
      ),
    ),
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
    'language choice': (tester) async {
      await tester.tap(find.byType(FilledButton));
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

          await tester.pumpWidget(
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      FavouritesCubit(favourites, initial: favourites.saved),
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
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
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
