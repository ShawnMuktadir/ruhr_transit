import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/platform_chip.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_settings.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_trip_repository.dart';
import '../../../helpers/fake_vehicle_run_repository.dart';

void main() {
  late FakeTripRepository repository;

  setUp(() {
    repository = FakeTripRepository();
    getIt
      ..registerFactory<TripRepository>(() => repository)
      ..registerFactory<VehicleRunRepository>(FakeVehicleRunRepository.new);
  });
  tearDown(getIt.reset);

  // Above MaterialApp like in the app; the bookmark on every page reads it.
  Widget app(Widget home) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) =>
            FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
      ),
      BlocProvider(
        create: (_) =>
            ProfileCubit(FakeProfileRepository(), FakeAuthRepository()),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Times show in the device time zone; 24-hour format fixes the pattern.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      home: home,
    ),
  );

  String localTime(DateTime utc) {
    final local = utc.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  group('trip form', () {
    late List<String> pickerTitles;
    late List<Stop?> picks;

    Future<void> pumpForm(WidgetTester tester) async {
      pickerTitles = [];
      await tester.pumpWidget(
        app(
          BlocProvider(
            create: (_) => TripFormCubit(),
            child: TripFormView(
              pickStop: (context, {required title}) async {
                pickerTitles.add(title);
                return picks.removeAt(0);
              },
            ),
          ),
        ),
      );
    }

    FilledButton searchButton(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('picks both stops, swaps them and searches', (tester) async {
      picks = [bochumHbf, dortmundHbf];
      await pumpForm(tester);
      expect(searchButton(tester).onPressed, isNull);

      await tester.tap(find.text('Choose start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose destination'));
      await tester.pumpAndSettle();

      expect(pickerTitles, ['Choose start', 'Choose destination']);
      expect(find.text('Bochum, Hbf'), findsOneWidget);
      expect(find.text('Dortmund, Hbf'), findsOneWidget);

      await tester.tap(find.byTooltip('Swap start and destination'));
      await tester.pump();
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.byType(TripResultsPage), findsOneWidget);
      final query = repository.queries.single;
      expect(query.from, dortmundHbf);
      expect(query.to, bochumHbf);
      expect(query.time, isA<LeaveNow>());
    });

    testWidgets('a cancelled pick keeps the form as it was', (tester) async {
      picks = [null];
      await pumpForm(tester);

      await tester.tap(find.text('Choose start'));
      await tester.pumpAndSettle();

      expect(find.text('Choose start'), findsOneWidget);
    });

    testWidgets('the same stop twice explains why search is off', (
      tester,
    ) async {
      picks = [bochumHbf, bochumHbf];
      await pumpForm(tester);

      await tester.tap(find.text('Choose start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose destination'));
      await tester.pumpAndSettle();

      expect(find.text('Start and destination are the same.'), findsOneWidget);
      expect(searchButton(tester).onPressed, isNull);
    });

    testWidgets('depart and arrive show date and time', (tester) async {
      picks = [];
      await pumpForm(tester);
      expect(find.byIcon(Icons.schedule), findsNothing);

      await tester.tap(find.text('Arrive'));
      await tester.pump();

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);

      await tester.tap(find.text('Now'));
      await tester.pump();
      expect(find.byIcon(Icons.schedule), findsNothing);
    });
  });

  group('trip results', () {
    const query = TripQuery(from: bochumHbf, to: dortmundHbf, time: LeaveNow());

    Future<void> pumpResults(WidgetTester tester) async {
      await tester.pumpWidget(
        app(
          BlocProvider(
            create: (_) => TripResultsCubit(
              repository,
              query,
              // Before the sample journeys leave.
              now: () => DateTime.utc(2026, 11, 2, 7),
            )..load(),
            child: const TripResultsView(query: query),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('cards show times, delays, lines and transfers', (
      tester,
    ) async {
      await pumpResults(tester);

      expect(find.text('Hbf → Hbf'), findsOneWidget);
      expect(find.text(localTime(directS1.departure.plannedTime)), findsOne);
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      // 07:17 to 07:39 as expected, not 07:14 to 07:37 as planned.
      expect(find.text('22 min'), findsOneWidget);
      expect(find.text('Direct'), findsOneWidget);
      expect(find.text('S1'), findsOneWidget);
      expect(find.text('U35'), findsOneWidget);
      expect(find.byIcon(Icons.directions_walk), findsOneWidget);
      expect(find.text('1 change'), findsOneWidget);
      // Only the trip with notices says so; S1 has none.
      expect(find.text('3 notices · Affects this trip'), findsOneWidget);
      expect(
        find.textContaining('All information without guarantee'),
        findsOne,
      );
    });

    testWidgets('a card is read as one sentence', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpResults(tester);

      final dep = localTime(directS1.departure.plannedTime);
      final arr = localTime(directS1.arrival.plannedTime);
      expect(
        find.bySemanticsLabel(
          'Departs $dep, 3 min late, arrives $arr, 2 min late, '
          '22 min, Direct, S1',
        ),
        findsOneWidget,
      );
      // Notices are part of the sentence, as on screen.
      expect(
        find.bySemanticsLabel(
          RegExp(r'1 change, U35, walk, 339, 3 notices, Affects this trip$'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('later trips are appended', (tester) async {
      repository.replies = [
        Ok([directS1]),
        Ok([laterRe11]),
      ];
      await pumpResults(tester);

      await tester.tap(find.text('Later trips'));
      await tester.pump();
      await tester.pump();

      expect(find.text('S1'), findsOneWidget);
      expect(find.text('RE11'), findsOneWidget);
      // RE11 has no live data; S1 has.
      expect(find.text('Timetable only'), findsOneWidget);
    });

    testWidgets('a card without live data says so, also to TalkBack', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      repository.replies = [
        Ok([laterRe11]),
      ];
      await pumpResults(tester);

      expect(find.text('Timetable only'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'RE11, Timetable only$')),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('no trips says so', (tester) async {
      repository.replies = [const Ok([])];
      await pumpResults(tester);

      expect(find.text('No trips found between these stops.'), findsOne);
    });

    testWidgets('a failure shows the error and retries', (tester) async {
      repository.replies = [
        const Err(NetworkFailure()),
        Ok([directS1]),
      ];
      await pumpResults(tester);
      expect(find.textContaining('No internet connection'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();

      expect(find.text('S1'), findsOneWidget);
    });

    testWidgets('a card opens the journey details', (tester) async {
      await pumpResults(tester);

      await tester.tap(find.text('U35'));
      await tester.pumpAndSettle();

      expect(find.byType(JourneyDetailsPage), findsOneWidget);
    });
  });

  /// Room for the whole details page: a warning opens the notices, which
  /// would push the rides out of the default 800x600 test screen.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  group('journey details: where the vehicle is', () {
    Future<void> pumpAt(
      WidgetTester tester,
      DateTime now, {
      FakeVehicleRunRepository? runs,
    }) async {
      tallScreen(tester);
      final repository = runs ?? FakeVehicleRunRepository();
      await tester.pumpWidget(
        app(
          JourneyDetailsPage(
            journey: withWalk,
            runs: () => repository,
            now: () => now,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    DateTime at(int hour, int minute) =>
        DateTime.utc(2026, 11, 2, hour, minute);

    testWidgets('on its way to the user: between two stops before boarding', (
      tester,
    ) async {
      await pumpAt(tester, at(7, 20));

      expect(
        find.text('Now between Bochum Lennershof and Bochum Ruhr-Universität'),
        findsOneWidget,
      );
      // On its last stretch to the boarding stop.
      expect(find.text('Vehicle is here'), findsOneWidget);
      // Collapsed even with the vehicle there, so the ride stays on top.
      expect(find.text('2 stops before'), findsOneWidget);
      expect(find.text('Bochum Hustadt'), findsNothing);
      await tester.tap(find.text('2 stops before'));
      await tester.pumpAndSettle();
      expect(find.text('Bochum Hustadt'), findsOneWidget);
      expect(find.text('Vehicle is here'), findsOneWidget);
      expect(find.text('Board'), findsOneWidget);
      expect(find.text('Get off'), findsOneWidget);
      // The stop after getting off stays collapsed.
      expect(find.text('1 stop after'), findsOneWidget);
      expect(find.text('Bochum Rathaus (Süd)'), findsNothing);
      // Replaces the plain list of stops in between.
      expect(find.text('2 stops in between'), findsNothing);
    });

    testWidgets('standing at a stop', (tester) async {
      await pumpAt(tester, at(7, 22));

      expect(find.text('Now at Bochum Gesundheitscampus'), findsOneWidget);
      expect(find.text('Vehicle is here'), findsNothing);
      expect(find.text('Bochum Hustadt'), findsNothing);
    });

    testWidgets('before the run has started', (tester) async {
      await pumpAt(tester, at(7, 10));

      expect(find.text('Departs Bochum Hustadt in 7 min'), findsOneWidget);
    });

    testWidgets('after the end', (tester) async {
      await pumpAt(tester, at(7, 40));

      expect(find.text('Trip ended'), findsOneWidget);
      expect(find.text('1 stop after'), findsOneWidget);
    });

    testWidgets('on the last stretch to the user, the marker is right above '
        'the boarding stop', (tester) async {
      // Between Lennershof (07:19) and Ruhr-Universität (07:21).
      await pumpAt(tester, at(7, 20));

      final marker = tester.getTopLeft(find.text('Vehicle is here')).dy;
      final board = tester.getTopLeft(find.text('Board')).dy;
      final before = tester.getTopLeft(find.text('2 stops before')).dy;
      expect(marker, greaterThan(before));
      expect(marker, lessThan(board));
    });

    testWidgets('says when the position is only the timetable', (tester) async {
      await pumpAt(
        tester,
        at(7, 22),
        runs: FakeVehicleRunRepository(Ok(VehicleRun(u35Run.stops))),
      );

      expect(find.text('By timetable, no live data'), findsOneWidget);
    });

    testWidgets('without the run, the ride shows as before', (tester) async {
      await pumpAt(
        tester,
        at(7, 22),
        runs: FakeVehicleRunRepository(const Err(NetworkFailure())),
      );

      expect(find.text('2 stops in between'), findsOneWidget);
      expect(find.textContaining('Now '), findsNothing);
    });

    testWidgets('a run that does not stop where the user boards is not '
        'shown', (tester) async {
      await pumpAt(
        tester,
        at(7, 22),
        runs: FakeVehicleRunRepository(
          Ok(VehicleRun(u35Run.stops.sublist(3), isRealtime: true)),
        ),
      );

      expect(find.text('2 stops in between'), findsOneWidget);
    });

    testWidgets('asks for the run of the ride', (tester) async {
      final runs = FakeVehicleRunRepository();
      await pumpAt(tester, at(7, 22), runs: runs);

      final ride = withWalk.legs.first as TransitLeg;
      expect(runs.keys.single, same(ride.runKey));
    });
  });

  group('journey details: stops in between and notices', () {
    testWidgets('a ride shows its stops in between on request', (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: withWalk, runs: null)),
      );
      expect(find.text('Bochum Markstr.'), findsNothing);

      await tester.ensureVisible(find.text('2 stops in between'));
      await tester.tap(find.text('2 stops in between'));
      await tester.pumpAndSettle();

      expect(find.text('Bochum Gesundheitscampus'), findsOneWidget);
      expect(find.text('Platform 2'), findsOneWidget);
    });

    testWidgets('a ride without stops in between shows nothing extra', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: directS1, runs: null)),
      );

      expect(find.textContaining('in between'), findsNothing);
      expect(find.textContaining('notice'), findsNothing);
    });

    testWidgets('notices are collapsed, then sorted and labelled', (
      tester,
    ) async {
      tallScreen(tester);
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: withWalk, runs: null)),
      );

      // Collapsed even with a warning; the heading's icon shows it.
      expect(find.text(rideNotice.title), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.byIcon(Icons.warning_amber),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('3 notices'));
      await tester.pumpAndSettle();

      final ride = tester.getTopLeft(find.text(rideNotice.title)).dy;
      final lift = tester.getTopLeft(find.text(liftNotice.title)).dy;
      final line = tester.getTopLeft(find.text(lineNotice.title)).dy;
      expect(ride, lessThan(lift));
      expect(lift, lessThan(line));
      expect(find.text('Affects this trip'), findsOneWidget);
      expect(find.text('Long-term change'), findsOneWidget);
      final tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text(rideNotice.title),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.tileColor, isNotNull);
      expect(find.text(liftNotice.text), findsOneWidget);
      expect(find.textContaining('in German only'), findsOneWidget);

      await tester.tap(find.text(lineNotice.title));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.textContaining('Dauer: 08.06.26'), findsOneWidget);
    });
  });

  group('journey details', () {
    testWidgets('shows rides, the walk and a short connection', (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: withWalk, runs: null)),
      );

      expect(find.text('towards Herne Schloß Strünkede'), findsOneWidget);
      expect(find.text('Bochum Ruhr-Universität'), findsOneWidget);
      expect(find.text('Gleis 3 (U)'), findsOneWidget);
      expect(find.text('Walk 4 min (183 m)'), findsOneWidget);
      // 4 minutes between the rides, all of them walking.
      expect(find.text('4 min to change · Short connection'), findsOneWidget);
      // The change row's own warning icon; the notices have theirs too.
      expect(
        find.descendant(
          of: find.ancestor(
            of: find.text('4 min to change · Short connection'),
            matching: find.byType(ListTile),
          ),
          matching: find.byIcon(Icons.warning_amber),
        ),
        findsOneWidget,
      );
      expect(find.text('Umleitung wegen Baustelle'), findsOneWidget);
    });

    testWidgets('a walk shows its directions on request', (tester) async {
      final semantics = tester.ensureSemantics();
      tallScreen(tester);
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: withWalk, runs: null)),
      );

      expect(find.text('Südring'), findsNothing);
      expect(
        tester.getSemantics(find.text('Show directions')),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          hasExpandedState: true,
          isExpanded: false,
          label: 'Show directions',
        ),
      );

      await tester.tap(find.text('Show directions'));
      await tester.pump();

      expect(find.text('Hide directions'), findsOneWidget);
      expect(find.text('Lift from level -2 to 0'), findsOneWidget);
      expect(find.text('Ausstieg U-Bahn U35 rechts'), findsOneWidget);
      expect(find.text('Get off'), findsOneWidget);
      // A way without a name.
      expect(find.text('Footpath'), findsOneWidget);
      expect(find.text('Straight on · 60 m'), findsOneWidget);
      expect(find.text('Turn right · 123 m'), findsOneWidget);
      expect(find.byIcon(Icons.turn_right), findsOneWidget);
      expect(
        find.bySemanticsLabel('Turn right, Südring, 123 metres'),
        findsOneWidget,
      );

      await tester.tap(find.text('Hide directions'));
      await tester.pump();
      expect(find.text('Südring'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a change inside a station has its way on the ride', (
      tester,
    ) async {
      tallScreen(tester);
      final ride = withWalk.legs.first as TransitLeg;
      final bus = withWalk.legs.last as TransitLeg;
      final journey = Journey([
        TransitLeg(
          line: ride.line,
          mode: ride.mode,
          direction: ride.direction,
          origin: ride.origin,
          destination: ride.destination,
          isRealtime: true,
          transferSteps: const [
            WalkStep(
              turn: WalkTurn.slightRight,
              name: 'Rolltreppe abwärts zur Ebene 0',
              distanceMeters: 9,
              duration: Duration(seconds: 18),
            ),
          ],
          transferPaths: const [
            StationPath(
              kind: StationPathKind.escalator,
              levelFrom: 1,
              levelTo: 0,
            ),
          ],
        ),
        bus,
      ]);
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: journey, runs: null)),
      );

      await tester.tap(find.text('Show directions'));
      await tester.pump();

      expect(find.text('Escalator from level 1 to 0'), findsOneWidget);
      expect(find.text('Rolltreppe abwärts zur Ebene 0'), findsOneWidget);
      expect(find.text('Bear right · 9 m'), findsOneWidget);
    });

    testWidgets('without live data the times are the timetable\'s', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: laterRe11, runs: null)),
      );

      expect(
        find.textContaining('No live data: all times are from the timetable'),
        findsOneWidget,
      );
      expect(find.text('Show directions'), findsNothing);
    });

    testWidgets('a direct trip has no change', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        app(JourneyDetailsPage(journey: directS1, runs: null)),
      );

      expect(find.textContaining('to change'), findsNothing);
      // EFA sends a bare "8"; the chip names it.
      expect(find.text('Platform 8'), findsOneWidget);
      expect(find.byType(PlatformChip), findsOneWidget);
      expect(find.textContaining('Direct'), findsOneWidget);
      semantics.dispose();
    });
  });
}
