import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/geo_point.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/map/base_map.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_map.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_map_page.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_favourites_repository.dart';
import '../../../helpers/fake_nearby_stops.dart';
import '../../../helpers/fake_trip_repository.dart';
import '../../../helpers/fake_vehicle_run_repository.dart';
import '../../../helpers/fixtures.dart';

void main() {
  // The disk cache needs a plugin that does not run in tests.
  setUpAll(
    () => BaseMap.tileProvider = () => NetworkTileProvider(
      cachingProvider: const DisabledMapCachingProvider(),
    ),
  );

  Widget app(Widget home) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
      ),
      BlocProvider(create: (_) => FavouritesCubit(FakeFavouritesRepository())),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  /// U35, a walk, bus 368: recorded with every point.
  final recorded = mapTripResponse(readEfaFixtureJson('trip_with_walk')).first;

  group('trip map', () {
    testWidgets('draws rides solid, walks dotted, marks start, change and '
        'destination, and says what it shows', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(TripMapPage(journey: recorded)));
      await tester.pump();

      final lines = tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(lines.polylines, hasLength(3));
      expect(lines.polylines[0].pattern, const StrokePattern.solid());
      expect(lines.polylines[1].pattern, isNot(const StrokePattern.solid()));
      expect(lines.polylines[0].points, hasLength(146));

      expect(find.byTooltip('Start'), findsOneWidget);
      expect(find.byTooltip('Change'), findsOneWidget);
      expect(find.byTooltip('Destination'), findsOneWidget);
      expect(find.textContaining('GeoBasis-DE / BKG'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'^Map of the trip from .+, 2 rides$')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('shows the vehicle where its run puts it', (tester) async {
      final ride = recorded.legs.first as TransitLeg;
      final start = ride.origin.plannedTime;
      final run = VehicleRun([
        RunStop(
          id: 'a',
          name: 'A',
          departurePlanned: start,
          position: const GeoPoint(51.44, 7.25),
        ),
        RunStop(
          id: 'b',
          name: 'B',
          arrivalPlanned: start.add(const Duration(minutes: 10)),
          position: const GeoPoint(51.48, 7.22),
        ),
      ]);
      await tester.pumpWidget(
        app(
          TripMapPage(
            journey: recorded,
            runs: () => FakeVehicleRunRepository(Ok(run)),
            now: () => start.add(const Duration(minutes: 5)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byTooltip('U35: position estimated from the times'),
        findsOneWidget,
      );
    });

    testWidgets('trip details offer the map only when there is something '
        'to draw', (tester) async {
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: recorded, runs: null)),
      );
      expect(find.byTooltip('Show on map'), findsOneWidget);

      await tester.tap(find.byTooltip('Show on map'));
      await tester.pumpAndSettle();
      expect(find.byType(TripMapPage), findsOneWidget);

      // The sample journeys have no points.
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: directS1, runs: null)),
      );
      expect(find.byTooltip('Show on map'), findsNothing);
    });
  });

  group('nearby map', () {
    testWidgets('switches from the list to pins, a pin opens its stop', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(
          BlocProvider(
            create: (_) => NearbyStopsCubit(
              FakeLocationSource()..permissionGranted = true,
              FakeNearbyStopsRepository(),
            )..load(),
            child: const NearbyStopsView(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(NearbyMap), findsNothing);

      await tester.tap(find.text('Map'));
      await tester.pump();
      await tester.pump();
      // The map lays out once before placing its markers.

      expect(find.byType(NearbyMap), findsOneWidget);
      expect(find.byTooltip('Your location'), findsOneWidget);
      expect(find.byIcon(Icons.location_on), findsNWidgets(nearbyStops.length));
      expect(find.byType(CircleLayer), findsOneWidget);

      await tester.tap(find.byIcon(Icons.location_on).first);
      await tester.pump();
      expect(find.textContaining('40 m away'), findsOneWidget);

      await tester.tap(find.text('List'));
      await tester.pump();
      expect(find.byType(NearbyMap), findsNothing);
    });
  });
}
