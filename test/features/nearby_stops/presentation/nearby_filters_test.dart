import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/map/base_map.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_map.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

import '../../../helpers/fake_favourites_repository.dart';
import '../../../helpers/fake_nearby_stops.dart';

Stop _stop(String name, Set<TransportMode> modes) => Stop(
  id: name,
  name: name,
  fullName: 'Bochum, $name',
  locality: 'Bochum',
  latitude: 51.479,
  longitude: 7.223,
  modes: modes,
);

void main() {
  // The disk cache needs a plugin that does not run in tests.
  setUpAll(
    () => BaseMap.tileProvider = () => NetworkTileProvider(
      cachingProvider: const DisabledMapCachingProvider(),
    ),
  );

  late FakeFavouritesRepository favourites;
  late FakeNearbyStopsRepository stops;

  setUp(() {
    favourites = FakeFavouritesRepository();
    stops = FakeNearbyStopsRepository()
      ..reply = Ok([
        NearbyStop(_stop('Bussteig', {TransportMode.bus}), distanceMeters: 50),
        NearbyStop(_stop('Tramstop', {TransportMode.tram}), distanceMeters: 60),
        NearbyStop(
          _stop('Bahnhof', {TransportMode.suburbanTrain}),
          distanceMeters: 70,
        ),
        NearbyStop(
          _stop('Knoten', {TransportMode.bus, TransportMode.tram}),
          distanceMeters: 80,
        ),
      ]);
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => FavouritesCubit(favourites, initial: favourites.saved),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider(
            create: (_) => NearbyStopsCubit(
              FakeLocationSource()..permissionGranted = true,
              stops,
            )..load(),
            child: const NearbyStopsView(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('star', () {
    testWidgets('saves a stop from the row and takes it back', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      expect(find.byTooltip('Add to favourites'), findsNWidgets(4));

      await tester.tap(find.byTooltip('Add to favourites').first);
      await tester.pump();

      expect(favourites.saved.single.name, 'Bussteig');
      expect(find.byTooltip('Remove from favourites'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);

      await tester.tap(find.byTooltip('Remove from favourites'));
      await tester.pump();
      expect(favourites.saved, isEmpty);
      semantics.dispose();
    });

    testWidgets('does not open the stop', (tester) async {
      await pump(tester);

      await tester.tap(find.byTooltip('Add to favourites').first);
      await tester.pumpAndSettle();

      expect(find.text('Stops near me'), findsOneWidget);
    });
  });

  group('chips', () {
    testWidgets('offer the modes that are here, all stops until one is on', (
      tester,
    ) async {
      await pump(tester);

      expect(find.widgetWithText(FilterChip, 'Bus'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Tram'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'Train'), findsOneWidget);
      // No stop here has it.
      expect(find.widgetWithText(FilterChip, 'U-Bahn'), findsNothing);
      for (final name in ['Bussteig', 'Tramstop', 'Bahnhof', 'Knoten']) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('filter the list; several add up; off shows all again', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Bus'));
      await tester.pump();
      expect(find.text('Bussteig'), findsOneWidget);
      expect(find.text('Knoten'), findsOneWidget);
      expect(find.text('Tramstop'), findsNothing);
      expect(find.text('Bahnhof'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Tram'));
      await tester.pump();
      expect(find.text('Tramstop'), findsOneWidget);
      expect(find.text('Bahnhof'), findsNothing);

      await tester.tap(find.widgetWithText(FilterChip, 'Bus'));
      await tester.tap(find.widgetWithText(FilterChip, 'Tram'));
      await tester.pump();
      expect(find.text('Bahnhof'), findsOneWidget);
    });

    testWidgets('"Train" includes the S-Bahn', (tester) async {
      await pump(tester);

      await tester.tap(find.widgetWithText(FilterChip, 'Train'));
      await tester.pump();

      expect(find.text('Bahnhof'), findsOneWidget);
      expect(find.text('Bussteig'), findsNothing);
    });

    testWidgets('filter the map too, and close a hidden stop\'s card', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Map'));
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<NearbyMap>(find.byType(NearbyMap)).stops,
        hasLength(4),
      );

      await tester.tap(find.byIcon(Icons.location_on).first);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('80 m away'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Train'));
      await tester.pump();
      await tester.pump();

      expect(
        tester.widget<NearbyMap>(find.byType(NearbyMap)).stops,
        hasLength(1),
      );
      expect(find.textContaining('80 m away'), findsNothing);
      expect(find.byType(FlutterMap), findsOneWidget);
    });

    testWidgets('one mode alone has nothing to choose between', (tester) async {
      stops.reply = Ok([
        NearbyStop(_stop('A', {TransportMode.bus}), distanceMeters: 50),
        NearbyStop(_stop('B', {TransportMode.bus}), distanceMeters: 60),
      ]);
      await pump(tester);

      expect(find.byType(FilterChip), findsNothing);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('choosing a stop', () {
    Icon pinOf(WidgetTester tester, int index) =>
        tester.widget<Icon>(find.byIcon(Icons.location_on).at(index));

    testWidgets('a tap in the list shows it on the map, pin highlighted', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(NearbyMap), findsNothing);

      await tester.tap(find.text('Tramstop'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(NearbyMap), findsOneWidget);
      final map = tester.widget<NearbyMap>(find.byType(NearbyMap));
      expect(map.selected?.stop.name, 'Tramstop');
      // Name, distance and the ring.
      expect(find.text('Tramstop'), findsOneWidget);
      expect(find.textContaining('60 m away'), findsOneWidget);
      final circles = tester.widget<CircleLayer>(find.byType(CircleLayer));
      expect(circles.circles, hasLength(2));
      // The chosen pin is last, so on top, and larger than the others.
      final pins = find.byIcon(Icons.location_on).evaluate().length;
      expect(pins, 4);
      expect(pinOf(tester, 3).size, greaterThan(pinOf(tester, 0).size!));
    });

    testWidgets('a tap on the map lets go of it', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Tramstop'));
      await tester.pump();
      await tester.pump();

      tester.widget<NearbyMap>(find.byType(NearbyMap)).onSelected(null);
      await tester.pump();

      expect(find.textContaining('60 m away'), findsNothing);
      expect(
        tester.widget<CircleLayer>(find.byType(CircleLayer)).circles,
        hasLength(1),
      );
    });

    testWidgets('a filter that hides the chosen stop lets go of it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Tramstop'));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.widgetWithText(FilterChip, 'Train'));
      await tester.pump();
      await tester.pump();

      expect(tester.widget<NearbyMap>(find.byType(NearbyMap)).selected, isNull);
      expect(find.textContaining('60 m away'), findsNothing);
    });
  });
}
