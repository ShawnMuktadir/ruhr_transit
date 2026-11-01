import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journey_button.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_list.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_stop_repository.dart';

void main() {
  late FakeFavouriteJourneysRepository repository;
  late List<FavouriteJourney> opened;

  final toWork = FavouriteJourney(
    from: bochumHbf,
    to: dortmundHbf,
    savedAt: DateTime.utc(2026, 11, 1, 7),
    label: 'Work',
  );
  final home = FavouriteJourney(
    from: dortmundHbf,
    to: bochumHbf,
    savedAt: DateTime.utc(2026, 11, 1, 8),
  );

  /// A list goes in the body, a button in the app bar, as in the app.
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    BlocProvider(
      create: (_) => FavouriteJourneysCubit(repository),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child is FavouriteJourneyButton
            ? Scaffold(appBar: AppBar(actions: [child]))
            : Scaffold(body: child),
      ),
    ),
  );

  Future<void> pumpList(WidgetTester tester) async {
    await pump(tester, FavouriteJourneysList(onOpen: opened.add));
    await tester.pump();
  }

  setUp(() {
    repository = FakeFavouriteJourneysRepository();
    opened = [];
  });

  group('FavouriteJourneysList', () {
    testWidgets('shows progress until the database answers', (tester) async {
      await pump(tester, FavouriteJourneysList(onOpen: opened.add));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('explains how to add one when empty', (tester) async {
      await pumpList(tester);

      expect(find.textContaining('No saved journeys yet'), findsOneWidget);
      expect(find.textContaining('tap the bookmark'), findsOneWidget);
    });

    testWidgets('a read error explains and retries', (tester) async {
      repository.readError = Exception('disk');
      await pumpList(tester);
      expect(find.text('Saved journeys could not be loaded.'), findsOneWidget);

      repository
        ..readError = null
        ..saved = [toWork];
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Bochum, Hbf → Dortmund, Hbf'), findsOneWidget);
    });

    testWidgets('lists journeys with their label; tap opens one', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      repository.saved = [home, toWork];
      await pumpList(tester);

      // Oldest first.
      final titles = tester
          .widgetList<Text>(find.textContaining(' → '))
          .map((text) => text.data);
      expect(titles, [
        'Bochum, Hbf → Dortmund, Hbf',
        'Dortmund, Hbf → Bochum, Hbf',
      ]);
      expect(find.text('Work'), findsOneWidget);
      // "→" would be read as "right arrow".
      expect(
        find.bySemanticsLabel(RegExp('Bochum, Hbf to Dortmund, Hbf')),
        findsOneWidget,
      );

      await tester.tap(find.text('Work'));
      expect(opened.single.to, dortmundHbf);
      semantics.dispose();
    });

    testWidgets('swiping removes a journey, undo brings it back', (
      tester,
    ) async {
      repository.saved = [toWork, home];
      await pumpList(tester);

      await tester.drag(find.text('Work'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsNothing);
      expect(repository.saved, hasLength(1));
      expect(find.text('Removed Bochum, Hbf → Dortmund, Hbf'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(find.text('Work'), findsOneWidget);
      // Back in its old place, first.
      expect(
        tester.widgetList<Text>(find.textContaining(' → ')).first.data,
        'Bochum, Hbf → Dortmund, Hbf',
      );
    });

    testWidgets('TalkBack can remove a journey with an action', (tester) async {
      final semantics = tester.ensureSemantics();
      repository.saved = [toWork];
      await pumpList(tester);

      tester.semantics.customAction(
        find.semantics.byLabel(RegExp('Bochum, Hbf to Dortmund, Hbf')),
        const CustomSemanticsAction(label: 'Remove'),
      );
      await tester.pumpAndSettle();

      expect(repository.saved, isEmpty);
      expect(find.text('Undo'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the menu edits the label and removes', (tester) async {
      repository.saved = [toWork];
      await pumpList(tester);

      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'RE1 at 7:40');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('RE1 at 7:40'), findsOneWidget);
      expect(repository.saved.single.label, 'RE1 at 7:40');

      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
    });

    testWidgets('cancelling the label dialog changes nothing', (tester) async {
      repository.saved = [toWork];
      await pumpList(tester);

      await tester.tap(find.byTooltip('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit label'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Gym');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.saved.single.label, 'Work');
    });
  });

  group('FavouriteJourneyButton', () {
    IconButton button(WidgetTester tester) =>
        tester.widget<IconButton>(find.byType(IconButton));

    Future<void> pumpButton(WidgetTester tester, Stop? from, Stop? to) async {
      await pump(tester, FavouriteJourneyButton(from: from, to: to));
      await tester.pump();
    }

    testWidgets('is off until both stops are chosen and different', (
      tester,
    ) async {
      await pumpButton(tester, bochumHbf, null);
      expect(button(tester).onPressed, isNull);

      await pumpButton(tester, bochumHbf, bochumHbf);
      expect(button(tester).onPressed, isNull);
    });

    testWidgets('saves and removes the journey, showing its state', (
      tester,
    ) async {
      await pumpButton(tester, bochumHbf, dortmundHbf);
      expect(button(tester).isSelected, isFalse);
      expect(find.byTooltip('Save journey'), findsOneWidget);

      await tester.tap(find.byTooltip('Save journey'));
      await tester.pumpAndSettle();
      expect(repository.saved.single.connects(bochumHbf, dortmundHbf), isTrue);
      expect(button(tester).isSelected, isTrue);
      expect(find.byTooltip('Remove saved journey'), findsOneWidget);

      await tester.tap(find.byTooltip('Remove saved journey'));
      await tester.pumpAndSettle();
      expect(repository.saved, isEmpty);
    });

    testWidgets('the other direction is a different journey', (tester) async {
      repository.saved = [home];
      await pumpButton(tester, bochumHbf, dortmundHbf);

      expect(button(tester).isSelected, isFalse);
    });
  });
}
