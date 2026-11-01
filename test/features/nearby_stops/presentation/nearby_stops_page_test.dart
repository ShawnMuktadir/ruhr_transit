import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_favourites_repository.dart';
import '../../../helpers/fake_nearby_stops.dart';
import '../../../helpers/fake_widget_sync.dart';

void main() {
  late FakeLocationSource location;
  late FakeNearbyStopsRepository repository;

  setUp(() {
    location = FakeLocationSource();
    repository = FakeNearbyStopsRepository();
    // Tapping a stop opens the real departures page.
    getIt
      ..registerFactory<DepartureRepository>(
        () => FakeDepartureRepository()..autoReply = const Ok([]),
      )
      ..registerSingleton<WidgetSync>(FakeWidgetSync());
  });
  tearDown(getIt.reset);

  Future<void> pumpPage(WidgetTester tester) async {
    final favourites = FakeFavouritesRepository();
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => FavouritesCubit(favourites),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider(
            create: (_) => NearbyStopsCubit(location, repository)..load(),
            child: const NearbyStopsView(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('lists the stops with their distance; tap opens the board', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Stops near me'), findsOneWidget);
    expect(find.text('Bochum · 40 m away'), findsOneWidget);
    expect(find.text('Dortmund · 350 m away'), findsOneWidget);
    expect(find.textContaining('approximate'), findsNothing);
    expect(find.textContaining('All information without guarantee'), findsOne);

    await tester.tap(find.text('Bochum · 40 m away'));
    await tester.pumpAndSettle();

    expect(find.byType(DeparturesPage), findsOneWidget);
  });

  testWidgets('shows progress while locating', (tester) async {
    final pending = location.pending = Completer();
    await pumpPage(tester);

    expect(find.text('Finding your location…'), findsOneWidget);
    final refresh = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.refresh),
    );
    expect(refresh.onPressed, isNull);

    pending.complete(bochumHbfLocation);
    await tester.pump();
    await tester.pump();
    expect(find.text('Bochum · 40 m away'), findsOneWidget);
  });

  testWidgets('approximate location shows a hint with a way out', (
    tester,
  ) async {
    location.result = const Located(
      latitude: 51.4,
      longitude: 7.2,
      isApproximate: true,
    );
    await pumpPage(tester);

    expect(find.textContaining('approximate location'), findsOneWidget);
    await tester.tap(find.text('Allow precise location'));
    expect(location.appSettingsOpened, 1);
  });

  testWidgets('no stops nearby says so', (tester) async {
    repository.reply = const Ok([]);
    await pumpPage(tester);

    expect(find.text('No stops within 1 km.'), findsOneWidget);
  });

  testWidgets('a failed request shows the error and retries', (tester) async {
    repository.reply = const Err(NetworkFailure());
    await pumpPage(tester);
    expect(find.textContaining('No internet connection'), findsOneWidget);

    repository.reply = const Ok(nearbyStops);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text('Bochum · 40 m away'), findsOneWidget);
  });

  testWidgets('denied permission explains and retries', (tester) async {
    location.result = const LocationPermissionDenied(permanently: false);
    await pumpPage(tester);

    expect(find.textContaining('only used for this search'), findsOneWidget);
    expect(find.text('App settings'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(location.calls, 2);
  });

  testWidgets('permanently denied permission opens the app settings', (
    tester,
  ) async {
    location.result = const LocationPermissionDenied(permanently: true);
    await pumpPage(tester);

    expect(find.textContaining('allowed in the app settings'), findsOne);
    await tester.tap(find.text('App settings'));
    expect(location.appSettingsOpened, 1);

    // Back from the settings, the user tries again.
    location.result = bochumHbfLocation;
    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Bochum · 40 m away'), findsOneWidget);
  });

  testWidgets('location off opens the location settings', (tester) async {
    location.result = const LocationOff();
    await pumpPage(tester);

    expect(find.textContaining('Location is turned off'), findsOneWidget);
    await tester.tap(find.text('Location settings'));
    expect(location.locationSettingsOpened, 1);
  });

  testWidgets('no position in time asks to try again', (tester) async {
    location.result = const LocationTimeout();
    await pumpPage(tester);

    expect(find.textContaining('could not be found'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
