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
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_tile.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_favourites_repository.dart';
import '../../../helpers/fake_nearby_stops.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_widget_sync.dart';

void main() {
  late FakeStopRepository repository;
  late FakeFavouritesRepository favourites;

  setUp(() {
    repository = FakeStopRepository();
    favourites = FakeFavouritesRepository();
    // Tapping a stop opens the real departures page, which resolves its
    // dependencies through get_it.
    getIt
      ..registerFactory<DepartureRepository>(
        () => FakeDepartureRepository()..autoReply = const Ok([]),
      )
      ..registerSingleton<WidgetSync>(FakeWidgetSync())
      ..registerSingleton<LocationSource>(FakeLocationSource())
      ..registerFactory<NearbyStopsRepository>(FakeNearbyStopsRepository.new);
  });
  tearDown(getIt.reset);

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      // Above MaterialApp like in the app, so pushed routes see it too.
      BlocProvider(
        create: (_) => FavouritesCubit(favourites, initial: favourites.saved),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider(
            create: (_) => StopSearchCubit(repository),
            child: const StopSearchView(),
          ),
        ),
      ),
    );
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(find.byType(SearchBar), query);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  testWidgets('shows the hint before searching', (tester) async {
    await pumpPage(tester);

    expect(find.textContaining('at least two letters'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsNothing);
  });

  testWidgets('stops near me opens its page from the start screen', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Stops near me'));
    await tester.pumpAndSettle();

    expect(find.byType(NearbyStopsPage), findsOneWidget);
    expect(find.text('Bochum · 40 m away'), findsOneWidget);
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

  testWidgets('removing the last favourite shows the hint again', (
    tester,
  ) async {
    favourites.saved = [bochumHbf];
    await pumpPage(tester);

    await tester.drag(find.text('Bochum'), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(find.textContaining('at least two letters'), findsOneWidget);
  });
}
