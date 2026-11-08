import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/line_badge.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_favourites_repository.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_widget_sync.dart';

void main() {
  late FakeDepartureRepository repository;
  late FakeFavouritesRepository favourites;
  late FakeWidgetSync widgetSync;

  setUp(() {
    repository = FakeDepartureRepository();
    favourites = FakeFavouritesRepository();
    widgetSync = FakeWidgetSync();
  });

  Future<void> pumpPage(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => FavouritesCubit(favourites, initial: favourites.saved),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Times are shown in the device time zone, which differs between
          // machines; 24-hour format at least fixes the pattern.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              alwaysUse24HourFormat: true,
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: BlocProvider(
            create: (_) =>
                DeparturesCubit(repository, bochumHbf.id, now: () => boardTime)
                  ..load(),
            child: DeparturesView(stop: bochumHbf, widgetSync: widgetSync),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  String localTime(DateTime utc) {
    final local = utc.toLocal();
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  group('rows on narrow and wide screens', () {
    Future<Rect> destinationAt(WidgetTester tester, double width) async {
      tester.view
        ..physicalSize = Size(width * 3, 2400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      repository.autoReply = Ok([delayedRe16]);
      await pumpPage(tester);
      await tester.pump();
      return tester.getRect(find.text(delayedRe16.destination));
    }

    testWidgets('on a 360 dp phone the destination goes below the line', (
      tester,
    ) async {
      final destination = await destinationAt(tester, 360);
      final badge = tester.getRect(find.byType(LineBadge).first);
      expect(destination.top, greaterThanOrEqualTo(badge.bottom));
      // Whole words, not cut mid-word: it gets the row's full width.
      expect(destination.width, greaterThan(200));
    });

    testWidgets('on a wide screen line, destination and time share a row', (
      tester,
    ) async {
      final destination = await destinationAt(tester, 600);
      final badge = tester.getRect(find.byType(LineBadge).first);
      expect(destination.left, greaterThan(badge.right));
    });
  });

  testWidgets('shows the stop name and the board with attribution', (
    tester,
  ) async {
    repository.autoReply = Ok([delayedRe16, cancelledRe11, movedU35]);
    await pumpPage(tester);

    expect(repository.stopIds, [bochumHbf.id]);
    expect(find.text('Bochum, Hbf'), findsOneWidget);
    expect(find.textContaining('RE16', findRichText: true), findsOneWidget);
    expect(find.text('Essen Hauptbahnhof'), findsOneWidget);
    expect(find.text(localTime(delayedRe16.plannedTime)), findsOneWidget);
    expect(find.text('+12'), findsOneWidget);
    expect(find.text('Vorfahrt eines anderen Zuges'), findsOneWidget);
    expect(find.textContaining('All information without guarantee'), findsOne);
    expect(find.text('Updated ${localTime(boardTime)}'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });

  testWidgets('marks cancelled departures and platform changes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    repository.autoReply = Ok([cancelledRe11, movedU35]);
    await pumpPage(tester);

    expect(find.text('Cancelled'), findsOneWidget);
    final cancelledTime = tester.widget<Text>(
      find.text(localTime(cancelledRe11.plannedTime)),
    );
    expect(cancelledTime.style?.decoration, TextDecoration.lineThrough);
    expect(
      find.bySemanticsLabel(RegExp('Platform changed to Gleis 3 \\(U\\)')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('reads each departure as one sentence', (tester) async {
    final semantics = tester.ensureSemantics();
    repository.autoReply = Ok([delayedRe16, cancelledRe11]);
    await pumpPage(tester);

    final re16 = localTime(delayedRe16.plannedTime);
    final re11 = localTime(cancelledRe11.plannedTime);
    expect(
      find.bySemanticsLabel(
        'Train RE16, Essen Hauptbahnhof, $re16, 12 min late, Platform 3, '
        'Vorfahrt eines anderen Zuges',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Train RE11, Kassel Bahnhof Wilhelmshöhe, $re11, Cancelled, '
        'Platform 5',
      ),
      findsOneWidget,
    );

    // The same order when the row is stacked at large text.
    await pumpPage(tester, textScale: 2);
    expect(
      find.bySemanticsLabel(RegExp('^Train RE16, Essen Hauptbahnhof, ')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('shows the empty board', (tester) async {
    repository.autoReply = const Ok([]);
    await pumpPage(tester);

    expect(find.text('No departures from this stop right now.'), findsOne);
  });

  testWidgets('shows the error and retries', (tester) async {
    repository.autoReply = const Err(NetworkFailure());
    await pumpPage(tester);
    expect(find.textContaining('No internet connection'), findsOneWidget);

    repository.autoReply = Ok([delayedRe16]);
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(repository.stopIds, hasLength(2));
    expect(find.textContaining('RE16', findRichText: true), findsOneWidget);
  });

  testWidgets('pull to refresh updates the board', (tester) async {
    repository.autoReply = Ok([delayedRe16]);
    await pumpPage(tester);

    repository.autoReply = Ok([delayedRe16, movedU35]);
    await tester.fling(
      find.textContaining('RE16', findRichText: true),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(repository.stopIds, hasLength(2));
    expect(find.textContaining('U35', findRichText: true), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the board and shows a snack bar', (
    tester,
  ) async {
    repository.autoReply = Ok([delayedRe16]);
    await pumpPage(tester);

    repository.autoReply = const Err(TimeoutFailure());
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();

    expect(find.textContaining('RE16', findRichText: true), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('not responding'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the star adds and removes the stop from favourites', (
    tester,
  ) async {
    repository.autoReply = const Ok([]);
    await pumpPage(tester);
    expect(find.byIcon(Icons.star), findsNothing);

    await tester.tap(find.byTooltip('Add to favourites'));
    await tester.pump();

    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(favourites.saved, [bochumHbf]);

    await tester.tap(find.byTooltip('Remove from favourites'));
    await tester.pump();

    expect(find.byIcon(Icons.star_border), findsOneWidget);
    expect(favourites.saved, isEmpty);
  });

  testWidgets('without a connection shows the saved board as outdated', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final savedAt = DateTime.utc(2026, 10, 25, 16, 50);
    repository
      ..autoReply = const Err(NetworkFailure())
      ..savedBoard = DepartureBoard([movedU35], fetchedAt: savedAt);
    await pumpPage(tester);

    expect(find.textContaining('U35', findRichText: true), findsOneWidget);
    expect(
      find.text('Not updated – departures as of ${localTime(savedAt)}'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    // TalkBack announces the change, which is otherwise colour and icon.
    expect(
      tester.getSemantics(find.textContaining('Not updated')),
      isSemantics(isLiveRegion: true),
    );
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('No internet connection'),
      ),
      findsOneWidget,
    );

    // Back online: the board is live again.
    repository.autoReply = Ok([delayedRe16]);
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();

    expect(find.textContaining('RE16', findRichText: true), findsOneWidget);
    expect(find.text('Updated ${localTime(boardTime)}'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off), findsNothing);
    semantics.dispose();
  });

  testWidgets('the menu shows the stop and its board on the widget', (
    tester,
  ) async {
    repository.autoReply = Ok([delayedRe16]);
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show on home-screen widget'));
    await tester.pumpAndSettle();

    final (stop, board) = widgetSync.shown.single;
    expect(stop, bochumHbf);
    expect(board?.departures, [delayedRe16]);
    expect(board?.fetchedAt, boardTime);
    expect(
      find.text('“Bochum, Hbf” is shown on the home-screen widget'),
      findsOneWidget,
    );
    // No widget can be pinned here, so no action is offered.
    expect(find.text('Add widget'), findsNothing);
  });

  testWidgets('without a widget (iOS) the menu is not there', (tester) async {
    widgetSync.isAvailable = false;
    repository.autoReply = Ok([delayedRe16]);
    await pumpPage(tester);

    expect(find.byType(PopupMenuButton<void>), findsNothing);
  });

  testWidgets('offers to add the widget if the launcher can', (tester) async {
    widgetSync.canAdd = true;
    repository.autoReply = const Err(NetworkFailure());
    await pumpPage(tester);

    await tester.tap(find.byType(PopupMenuButton<void>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show on home-screen widget'));
    await tester.pumpAndSettle();

    // Without a board, the widget gets the stop only.
    expect(widgetSync.shown.single.$2, isNull);
    await tester.tap(find.text('Add widget'));
    expect(widgetSync.addCount, 1);
  });

  testWidgets('at large text the destination moves below line and time', (
    tester,
  ) async {
    repository.autoReply = Ok([delayedRe16]);
    await pumpPage(tester);
    final badge = find.byType(LineBadge);
    final destination = find.text('Essen Hauptbahnhof');
    // Side by side at normal size ...
    expect(
      tester.getTopLeft(destination).dx,
      greaterThan(tester.getTopRight(badge).dx),
    );

    await pumpPage(tester, textScale: 2);

    // ... below at 200 %, where three columns break words apart.
    expect(
      tester.getTopLeft(destination).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(badge).dy),
    );
  });
}
