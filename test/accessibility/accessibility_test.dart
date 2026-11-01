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
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

import '../helpers/fake_departure_repository.dart';
import '../helpers/fake_favourites_repository.dart';
import '../helpers/fake_nearby_stops.dart';
import '../helpers/fake_stop_repository.dart';
import '../helpers/fake_trip_repository.dart';
import '../helpers/fake_widget_sync.dart';

/// Every screen, in light and dark, at normal and 200 % font size, on a
/// phone-sized screen: no layout overflow (an overflow fails the test by
/// itself), and Android's tap target, label and contrast guidelines.
void main() {
  final screens = <String, Widget Function()>{
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
    'journey details': () => JourneyDetailsPage(journey: withWalk),
  };

  for (final MapEntry(key: name, value: build) in screens.entries) {
    for (final brightness in Brightness.values) {
      for (final textScale in [1.0, 2.0]) {
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
            BlocProvider(
              create: (_) =>
                  FavouritesCubit(favourites, initial: favourites.saved),
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

          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          semantics.dispose();
        });
      }
    }
  }
}
