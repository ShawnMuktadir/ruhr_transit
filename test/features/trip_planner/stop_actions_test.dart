import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_trip_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/trip_repository_impl.dart';
import 'package:ruhr_transit/features/trip_planner/domain/current_location_finder.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/walk_to_stop.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/stop_actions.dart';

import '../../helpers/fake_favourite_journeys_repository.dart';
import '../../helpers/fake_http_adapter.dart';
import '../../helpers/fake_nearby_stops.dart';
import '../../helpers/fake_stop_repository.dart';
import '../../helpers/fake_trip_repository.dart';
import '../../helpers/fixtures.dart';

DateTime _utc(int hour, int minute) => DateTime.utc(2026, 11, 4, hour, minute);

/// 6 minutes on foot with one step.
final _walk = Journey([
  WalkLeg(
    duration: const Duration(minutes: 6),
    distanceMeters: 374,
    origin: TripStop(name: 'Kortumstr. 10', plannedTime: _utc(18, 0)),
    destination: TripStop(name: 'Bochum Hbf', plannedTime: _utc(18, 6)),
    steps: const [
      WalkStep(
        turn: WalkTurn.right,
        name: 'Südring',
        distanceMeters: 374,
        duration: Duration(minutes: 6),
      ),
    ],
  ),
]);

void main() {
  group('walkRoute', () {
    late FakeHttpAdapter adapter;

    TripRepositoryImpl answering(String body, {int status = 200}) {
      adapter = FakeHttpAdapter(
        (_) async => textResponse(body, statusCode: status),
      );
      return TripRepositoryImpl(
        EfaTripRemoteSource(
          createEfaDio(baseUrl: 'https://efa.test/openservice')
            ..httpClientAdapter = adapter,
        ),
      );
    }

    test('asks for a trip without any transport, gets the walk', () async {
      final repository = answering(readEfaFixture('trip_walk_only'));

      final result = await repository.walkRoute(
        from: kortumstr10,
        to: bochumHbf,
      );

      final query = adapter.requests.single.uri.queryParameters;
      expect(query['name_origin'], kortumstr10.id);
      expect(query['name_destination'], bochumHbf.id);
      expect(query['excludedMeans'], 'checkbox');
      expect(query['exclMOT_0'], '1');
      expect(query['exclMOT_11'], '1');

      final walk = (result as Ok<Journey?>).value!.legs.single as WalkLeg;
      expect(walk.distanceMeters, 374);
      expect(walk.steps, hasLength(3));
      expect(walk.path, hasLength(33));
    });

    test('nothing walkable is Ok(null)', () async {
      final repository = answering('{"journeys":[]}');

      final result = await repository.walkRoute(
        from: kortumstr10,
        to: bochumHbf,
      );

      expect(result, isA<Ok<Journey?>>().having((r) => r.value, 'value', null));
    });

    test('a server error stays an error', () async {
      final repository = answering('oops', status: 500);

      final result = await repository.walkRoute(
        from: kortumstr10,
        to: bochumHbf,
      );

      expect(result, isA<Err<Journey?>>());
    });

    test('a request that cannot connect is a NetworkFailure', () async {
      final repository = TripRepositoryImpl(
        EfaTripRemoteSource(
          createEfaDio(baseUrl: 'https://efa.test/openservice')
            ..httpClientAdapter = FakeHttpAdapter(
              (options) async => throw DioException.connectionError(
                requestOptions: options,
                reason: 'offline',
              ),
            ),
        ),
      );

      expect(
        await repository.walkRoute(from: kortumstr10, to: bochumHbf),
        isA<Err<Journey?>>().having(
          (r) => r.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
      );
    });
  });

  group('WalkToStop', () {
    late FakeLocationSource location;
    late FakeTripRepository trips;
    late WalkToStop walk;

    setUp(() {
      location = FakeLocationSource();
      trips = FakeTripRepository();
      walk = WalkToStop(
        CurrentLocationFinder(location, FakeStopRepository()),
        trips,
      );
    });

    test('from the address where the user is, to the stop', () async {
      trips.walkReply = Ok(_walk);

      final result = await walk.find(bochumHbf);

      expect(result, isA<WalkFound>());
      expect(trips.walks.single, (kortumstr10, bochumHbf));
    });

    test('without a location it says why and asks nothing', () async {
      location.result = const LocationOff();

      final result = await walk.find(bochumHbf);

      expect(
        result,
        isA<WalkNoLocation>().having(
          (r) => r.problem,
          'problem',
          isA<HereLocationOff>(),
        ),
      );
      expect(trips.walks, isEmpty);
    });

    test('no walk, or one far too long, is not found', () async {
      expect(await walk.find(bochumHbf), isA<WalkNotFound>());

      trips.walkReply = Ok(
        Journey([
          WalkLeg(
            duration: const Duration(hours: 3),
            origin: TripStop(name: 'A', plannedTime: _utc(8, 0)),
            destination: TripStop(name: 'B', plannedTime: _utc(11, 0)),
          ),
        ]),
      );
      expect(await walk.find(bochumHbf), isA<WalkNotFound>());
    });

    test('a failed request says so', () async {
      trips.walkReply = const Err(TimeoutFailure());

      expect(await walk.find(bochumHbf), isA<WalkFailed>());
    });
  });

  group('StopActions', () {
    late List<Stop> from;
    late List<Stop> to;
    late FakeLocationSource location;
    late FakeTripRepository trips;

    setUp(() {
      from = [];
      to = [];
      location = FakeLocationSource();
      trips = FakeTripRepository();
    });

    Widget app({bool withActions = true}) {
      const page = Scaffold(body: StopActions(bochumHbf));
      return BlocProvider(
        create: (_) =>
            FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: withActions
              ? (context, child) => TripActions(
                  planFrom: from.add,
                  planTo: to.add,
                  walkToStop: () => WalkToStop(
                    CurrentLocationFinder(location, FakeStopRepository()),
                    trips,
                  ),
                  child: child!,
                )
              : null,
          home: page,
        ),
      );
    }

    testWidgets('fill the planner with the stop', (tester) async {
      await tester.pumpWidget(app());

      await tester.tap(find.text('From here'));
      await tester.tap(find.text('To here'));

      expect(from, [bochumHbf]);
      expect(to, [bochumHbf]);
    });

    testWidgets('show nothing without the home shell', (tester) async {
      await tester.pumpWidget(app(withActions: false));

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('a walk opens with its directions showing', (tester) async {
      trips.walkReply = Ok(_walk);
      await tester.pumpWidget(app());

      await tester.tap(find.text('Walk there'));
      await tester.pumpAndSettle();

      expect(find.byType(JourneyDetailsPage), findsOneWidget);
      expect(find.textContaining('On foot'), findsOneWidget);
      expect(find.text('Walk 6 min (374 m)'), findsOneWidget);
      expect(find.text('Südring'), findsOneWidget);
      expect(find.text('Hide directions'), findsOneWidget);
    });

    testWidgets('location off offers the settings', (tester) async {
      location.result = const LocationOff();
      await tester.pumpWidget(app());

      await tester.tap(find.text('Walk there'));
      await tester.pumpAndSettle();

      expect(find.text('Location services are turned off.'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      expect(location.locationSettingsOpened, 1);
    });

    testWidgets('no route and failures say so', (tester) async {
      await tester.pumpWidget(app());

      await tester.tap(find.text('Walk there'));
      await tester.pumpAndSettle();
      expect(find.text('No walking route found.'), findsOneWidget);

      trips.walkReply = const Err(NetworkFailure());
      await tester.tap(find.text('Walk there'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No internet connection'), findsOneWidget);
    });
  });
}
