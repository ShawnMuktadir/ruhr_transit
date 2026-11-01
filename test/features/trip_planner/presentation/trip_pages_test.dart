import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/platform_chip.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_trip_repository.dart';

void main() {
  late FakeTripRepository repository;

  setUp(() {
    repository = FakeTripRepository();
    getIt.registerFactory<TripRepository>(() => repository);
  });
  tearDown(getIt.reset);

  // Above MaterialApp like in the app; the bookmark on every page reads it.
  Widget app(Widget home) => BlocProvider(
    create: (_) => FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
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
      expect(find.text('2 notices'), findsOneWidget);
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
        find.bySemanticsLabel(RegExp(r'1 change, U35, walk, 339, 2 notices$')),
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

  group('journey details: stops in between and notices', () {
    testWidgets('a ride shows its stops in between on request', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(JourneyDetailsPage(journey: withWalk)));
      expect(find.text('Bochum Markstr.'), findsNothing);

      expect(
        tester.getSemantics(find.text('2 stops in between')),
        matchesSemantics(
          label: '2 stops in between',
          isButton: true,
          hasExpandedState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.tap(find.text('2 stops in between'));
      await tester.pumpAndSettle();

      expect(find.text('Bochum Gesundheitscampus'), findsOneWidget);
      expect(find.text('Bochum Markstr.'), findsOneWidget);
      // Live time and platform chip, like origin and destination.
      expect(find.text('Platform 2'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('2 stops in between')),
        matchesSemantics(
          label: '2 stops in between',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('a ride without stops in between shows nothing extra', (
      tester,
    ) async {
      await tester.pumpWidget(app(JourneyDetailsPage(journey: directS1)));

      expect(find.textContaining('in between'), findsNothing);
      expect(find.textContaining('notice'), findsNothing);
    });

    testWidgets('notices are collapsed, important first, full text on tap', (
      tester,
    ) async {
      await tester.pumpWidget(app(JourneyDetailsPage(journey: withWalk)));
      expect(find.text(liftNotice.title), findsNothing);

      await tester.tap(find.text('2 notices'));
      await tester.pumpAndSettle();
      final titles = [
        tester.getTopLeft(find.text(liftNotice.title)).dy,
        tester.getTopLeft(find.text(lineNotice.title)).dy,
      ];
      expect(titles.first, lessThan(titles.last));
      expect(find.text(lineNotice.summary!), findsOneWidget);
      // Without a summary, the text tells same-titled notices apart.
      expect(find.text(liftNotice.text), findsOneWidget);
      // In English the app says the texts are German.
      expect(find.textContaining('in German only'), findsOneWidget);

      await tester.tap(find.text(lineNotice.title));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.textContaining('Dauer: 08.06.26'), findsOneWidget);
    });
  });

  group('journey details', () {
    testWidgets('shows rides, the walk and a short connection', (tester) async {
      await tester.pumpWidget(app(JourneyDetailsPage(journey: withWalk)));

      expect(find.text('towards Herne Schloß Strünkede'), findsOneWidget);
      expect(find.text('Bochum Ruhr-Universität'), findsOneWidget);
      expect(find.text('Gleis 3 (U)'), findsOneWidget);
      expect(find.text('Walk 4 min (183 m)'), findsOneWidget);
      // 4 minutes between the rides, all of them walking.
      expect(find.text('4 min to change · Short connection'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber), findsOneWidget);
      expect(find.text('Umleitung wegen Baustelle'), findsOneWidget);
    });

    testWidgets('a direct trip has no change', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(app(JourneyDetailsPage(journey: directS1)));

      expect(find.textContaining('to change'), findsNothing);
      // EFA sends a bare "8"; the chip names it.
      expect(find.text('Platform 8'), findsOneWidget);
      expect(find.byType(PlatformChip), findsOneWidget);
      expect(find.textContaining('Direct'), findsOneWidget);
      semantics.dispose();
    });
  });
}
