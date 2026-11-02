import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/recent_stops/presentation/recent_stops_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_tile.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_favourites_repository.dart';
import '../../../helpers/fake_recent_stops_repository.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_widget_sync.dart';

void main() {
  late FakeStopRepository repository;
  late FakeFavouritesRepository favourites;
  late FakeRecentStopsRepository recent;

  setUp(() {
    repository = FakeStopRepository();
    favourites = FakeFavouritesRepository();
    recent = FakeRecentStopsRepository();
    // Tapping a stop opens the real departures page, which resolves its
    // dependencies through get_it.
    getIt
      ..registerFactory<DepartureRepository>(
        () => FakeDepartureRepository()..autoReply = const Ok([]),
      )
      ..registerSingleton<WidgetSync>(FakeWidgetSync());
  });
  tearDown(getIt.reset);

  Future<void> pumpPage(
    WidgetTester tester, {
    ValueChanged<Stop>? onPicked,
  }) async {
    await tester.pumpWidget(
      // Above MaterialApp like in the app, so pushed routes see it too.
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                FavouritesCubit(favourites, initial: favourites.saved),
          ),
          BlocProvider(
            create: (_) => RecentStopsCubit(recent, initial: recent.saved),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider(
            create: (_) => StopSearchCubit(repository),
            child: StopSearchView(
              onPicked: onPicked,
              title: onPicked == null ? null : 'Choose start',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(TextField), query);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('shows the hint before searching', (tester) async {
    await pumpPage(tester);

    expect(find.textContaining('at least two letters'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('pick mode returns the stop instead of opening its board', (
    tester,
  ) async {
    final picked = <Stop>[];
    favourites.saved = [dortmundHbf];
    repository.autoReply = const Ok([bochumHbf]);
    await pumpPage(tester, onPicked: picked.add);

    expect(find.text('Choose start'), findsOneWidget);

    await tester.tap(find.text('Dortmund'));
    await search(tester, 'Bochum');
    await tester.tap(find.byType(StopTile));
    await tester.pumpAndSettle();

    expect(picked, [dortmundHbf, bochumHbf]);
    expect(find.byType(DeparturesPage), findsNothing);
  });

  testWidgets('shows results and opens the departures on tap', (tester) async {
    // Needed to find the transport icons by their screen reader labels.
    // ListTile merges them into one label per row, e.g. "Hbf\nBochum\nTrain…".
    final semantics = tester.ensureSemantics();
    repository.autoReply = const Ok([bochumHbf, dortmundHbf]);
    await pumpPage(tester);

    await search(tester, 'Hbf');

    expect(find.text('Bochum'), findsOneWidget);
    expect(find.text('Dortmund'), findsOneWidget);
    // Only Bochum Hbf has train service in the fake data.
    expect(
      find.bySemanticsLabel(RegExp('Bochum.*Train', dotAll: true)),
      findsOneWidget,
    );
    // Must be disposed inside the test body; tear-downs run too late.
    semantics.dispose();

    await tester.tap(find.text('Bochum'));
    await tester.pumpAndSettle();

    expect(find.byType(DeparturesPage), findsOneWidget);
    expect(find.text('Bochum, Hbf'), findsOneWidget);
    expect(find.textContaining('All information without guarantee'), findsOne);
  });

  testWidgets('shows the empty state with the query', (tester) async {
    repository.autoReply = const Ok([]);
    await pumpPage(tester);

    await search(tester, 'xqzzqxv');

    expect(find.text('No stops found for “xqzzqxv”.'), findsOneWidget);
  });

  testWidgets('shows the error and retries', (tester) async {
    repository.autoReply = const Err(TimeoutFailure());
    await pumpPage(tester);

    await search(tester, 'Bochum');
    expect(find.textContaining('not responding'), findsOneWidget);

    repository.autoReply = const Ok([bochumHbf]);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(repository.queries, ['Bochum', 'Bochum']);
    expect(find.text('Bochum'), findsWidgets);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('clear button empties the field and returns to the hint', (
    tester,
  ) async {
    repository.autoReply = const Ok([bochumHbf]);
    await pumpPage(tester);
    await search(tester, 'Bochum');
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();

    // Only the "Stops near me" entry is left; no search results.
    expect(find.byType(StopTile), findsNothing);
    expect(find.textContaining('at least two letters'), findsOneWidget);
  });

  testWidgets('shows favourites instead of the hint before searching', (
    tester,
  ) async {
    favourites.saved = [dortmundHbf, bochumHbf];
    await pumpPage(tester);

    expect(find.text('Favourites'), findsOneWidget);
    expect(find.textContaining('at least two letters'), findsNothing);
    final localities = tester
        .widgetList<Text>(
          find.descendant(
            of: find.byType(ListTile),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data)
        .where((text) => text == 'Bochum' || text == 'Dortmund');
    expect(localities, ['Dortmund', 'Bochum']);

    await tester.tap(find.text('Dortmund'));
    await tester.pumpAndSettle();

    expect(find.byType(DeparturesPage), findsOneWidget);
    expect(find.text('Dortmund, Hbf'), findsOneWidget);
    // The star on the board knows the stop is a favourite.
    expect(find.byTooltip('Remove from favourites'), findsOneWidget);
  });

  testWidgets('search results replace the favourites while typing', (
    tester,
  ) async {
    favourites.saved = [bochumHbf];
    repository.autoReply = const Ok([dortmundHbf]);
    await pumpPage(tester);

    await search(tester, 'Dortmund');

    expect(find.text('Favourites'), findsNothing);
    expect(find.byType(ListTile), findsOneWidget);
  });

  testWidgets('swiping removes a favourite, undo brings it back', (
    tester,
  ) async {
    favourites.saved = [bochumHbf, dortmundHbf];
    await pumpPage(tester);

    await tester.drag(find.text('Bochum'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Bochum'), findsNothing);
    expect(favourites.saved, [dortmundHbf]);
    expect(find.text('Removed “Bochum, Hbf” from favourites'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(favourites.saved, [bochumHbf, dortmundHbf]);
    expect(find.text('Bochum'), findsOneWidget);
  });

  testWidgets('TalkBack can remove a favourite with an action', (tester) async {
    final semantics = tester.ensureSemantics();
    favourites.saved = [bochumHbf, dortmundHbf];
    await pumpPage(tester);
    // With TalkBack on, MediaQuery reports accessible navigation.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pump();

    const remove = CustomSemanticsAction(label: 'Remove from favourites');
    final node = tester.getSemantics(find.text('Bochum'));
    expect(
      node.getSemanticsData().customSemanticsActionIds,
      contains(CustomSemanticsAction.getIdentifier(remove)),
    );
    tester.semantics.customAction(
      find.semantics.byLabel(RegExp('Bochum')),
      remove,
    );
    await tester.pumpAndSettle();
    expect(favourites.saved, [dortmundHbf]);

    // The undo snack bar must not time out while the user finds it.
    // Flutter keeps snack bars with an action open (SnackBar.persist); this
    // guards against that default changing.
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(favourites.saved, [bochumHbf, dortmundHbf]);
    semantics.dispose();
  });

  testWidgets('removing the last favourite shows the hint again', (
    tester,
  ) async {
    favourites.saved = [bochumHbf];
    await pumpPage(tester);

    await tester.drag(find.text('Bochum'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('at least two letters'), findsOneWidget);
  });

  group('recent stops in the From/To picker', () {
    testWidgets('shows the history below favourites, without repeating '
        'them', (tester) async {
      favourites.saved = [dortmundHbf];
      recent.saved = [bochumHbf, dortmundHbf];
      await pumpPage(tester, onPicked: (_) {});

      expect(find.text('Recent'), findsOneWidget);
      expect(find.text('Clear history'), findsOneWidget);
      // Dortmund is a favourite, so only Bochum is listed as recent.
      expect(find.text('Bochum'), findsOneWidget);
      expect(find.text('Dortmund'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Recent')).dy,
        greaterThan(tester.getTopLeft(find.text('Favourites')).dy),
      );
    });

    testWidgets('the history alone replaces the hint', (tester) async {
      recent.saved = [bochumHbf];
      await pumpPage(tester, onPicked: (_) {});

      expect(find.textContaining('at least two letters'), findsNothing);
      expect(find.byIcon(Icons.history), findsOneWidget);
    });

    testWidgets('tapping a recent stop picks it', (tester) async {
      final picked = <Stop>[];
      recent.saved = [bochumHbf];
      await pumpPage(tester, onPicked: picked.add);

      await tester.tap(find.text('Bochum'));

      expect(picked, [bochumHbf]);
    });

    testWidgets('no history outside the picker', (tester) async {
      recent.saved = [bochumHbf];
      await pumpPage(tester);

      expect(find.text('Recent'), findsNothing);
    });

    testWidgets('one stop can be removed, with undo', (tester) async {
      final semantics = tester.ensureSemantics();
      recent.saved = [bochumHbf, dortmundHbf];
      await pumpPage(tester, onPicked: (_) {});

      await tester.drag(find.text('Bochum'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(recent.saved, [dortmundHbf]);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(recent.saved, [bochumHbf, dortmundHbf]);

      // TalkBack users get an action instead of the swipe.
      tester.semantics.customAction(
        find.semantics.byLabel(RegExp('Dortmund')),
        const CustomSemanticsAction(label: 'Remove from history'),
      );
      await tester.pumpAndSettle();
      expect(recent.saved, [bochumHbf]);
      semantics.dispose();
    });

    testWidgets('clearing the history can be undone', (tester) async {
      recent.saved = [bochumHbf, dortmundHbf];
      await pumpPage(tester, onPicked: (_) {});

      await tester.tap(find.text('Clear history'));
      await tester.pumpAndSettle();
      expect(recent.saved, isEmpty);
      expect(find.text('History cleared'), findsOneWidget);
      expect(find.textContaining('at least two letters'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(recent.saved, [bochumHbf, dortmundHbf]);
    });

    testWidgets('a stop picked for From or To goes to the top', (tester) async {
      recent.saved = [dortmundHbf];
      getIt.registerFactory<StopRepository>(
        () => FakeStopRepository()..autoReply = const Ok([bochumHbf]),
      );
      Stop? picked;
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => FavouritesCubit(favourites)),
            BlocProvider(
              create: (_) => RecentStopsCubit(recent, initial: recent.saved),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    picked = await StopPicker.pick(context, title: 'From'),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await search(tester, 'Bochum');
      await tester.tap(find.text('Hbf').last);
      await tester.pumpAndSettle();

      expect(picked, bochumHbf);
      expect(recent.saved, [bochumHbf, dortmundHbf]);
    });
  });
}
