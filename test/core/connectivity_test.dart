import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/connectivity/connectivity.dart';
import 'package:ruhr_transit/core/connectivity/offline_banner.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

import '../helpers/fake_connectivity.dart';
import '../helpers/fake_departure_repository.dart';
import '../helpers/fake_favourite_journeys_repository.dart';
import '../helpers/fake_favourites_repository.dart';
import '../helpers/fake_stop_repository.dart';
import '../helpers/fake_trip_repository.dart';
import '../helpers/fake_widget_sync.dart';

void main() {
  late FakeConnectivitySource source;

  setUp(() => source = FakeConnectivitySource());

  /// The app's frame: connectivity above MaterialApp, banner in builder.
  Widget app(Widget home) => MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => ConnectivityCubit(source)),
      BlocProvider(create: (_) => FavouritesCubit(FakeFavouritesRepository())),
      BlocProvider(
        create: (_) =>
            FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => OfflineBanner(child: child!),
      home: home,
    ),
  );

  Future<void> goOffline(WidgetTester tester) async {
    source.set(online: false);
    await tester.pumpAndSettle();
  }

  Future<void> goOnline(WidgetTester tester) async {
    source.set(online: true);
    await tester.pump();
    await tester.pump();
  }

  test('the cubit follows Android, starting online', () async {
    final cubit = ConnectivityCubit(source);
    expect(cubit.state, isTrue);

    source.set(online: false);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isFalse);

    await cubit.close();
  });

  testWidgets('the banner shows only while offline, also to TalkBack', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(const Scaffold(body: Text('page'))));
    await tester.pump();
    expect(find.text('No internet connection'), findsNothing);

    await goOffline(tester);
    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.bySemanticsLabel('No internet connection'), findsOneWidget);
    expect(find.text('page'), findsOneWidget);

    await goOnline(tester);
    await tester.pumpAndSettle();
    expect(find.text('No internet connection'), findsNothing);
    semantics.dispose();
  });

  testWidgets('without the cubit, OnReconnect is just its child', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: OnReconnect(
          onReconnect: () => fail('called'),
          child: const Text('x'),
        ),
      ),
    );

    expect(find.text('x'), findsOneWidget);
  });

  testWidgets('a departure board that failed offline loads when back online', (
    tester,
  ) async {
    final departures = FakeDepartureRepository()
      ..autoReply = const Err(NetworkFailure());
    await tester.pumpWidget(
      app(
        BlocProvider(
          create: (_) =>
              DeparturesCubit(departures, bochumHbf.id, now: () => boardTime)
                ..load(),
          child: DeparturesView(stop: bochumHbf, widgetSync: FakeWidgetSync()),
        ),
      ),
    );
    await tester.pump();
    await goOffline(tester);
    expect(departures.stopIds, hasLength(1));

    departures.autoReply = Ok([delayedRe16]);
    await goOnline(tester);

    expect(departures.stopIds, hasLength(2));
    expect(find.textContaining('RE16', findRichText: true), findsOneWidget);
    expect(find.text('No internet connection'), findsNothing);
  });

  testWidgets('trips that failed offline are searched again when back online, '
      'trips shown are left alone', (tester) async {
    final trips = FakeTripRepository()..replies = [const Err(NetworkFailure())];
    const query = TripQuery(from: bochumHbf, to: dortmundHbf, time: LeaveNow());
    await tester.pumpWidget(
      app(
        BlocProvider(
          create: (_) => TripResultsCubit(
            trips,
            query,
            now: () => DateTime.utc(2026, 11, 2, 7),
          )..load(),
          child: const TripResultsView(query: query),
        ),
      ),
    );
    await tester.pump();
    await goOffline(tester);

    trips.replies = [
      Ok([directS1, withWalk]),
    ];
    await goOnline(tester);
    final searches = trips.queries.length;
    expect(searches, greaterThan(1));
    expect(find.textContaining('S1', findRichText: true), findsOneWidget);

    // Loaded: another drop-out and return change nothing.
    await goOffline(tester);
    await goOnline(tester);
    expect(trips.queries, hasLength(searches));
  });
}
