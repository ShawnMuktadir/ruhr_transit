import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/app.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

import 'helpers/fake_departure_repository.dart';

import 'helpers/fake_favourites_repository.dart';
import 'helpers/fake_stop_repository.dart';
import 'helpers/fake_widget_sync.dart';

void main() {
  late FakeWidgetSync widgetSync;

  // The real app resolves the repositories through get_it; fakes keep the
  // smoke tests off the network and the platform.
  setUp(() {
    widgetSync = FakeWidgetSync();
    getIt
      ..registerFactory<StopRepository>(FakeStopRepository.new)
      ..registerFactory<DepartureRepository>(
        () => FakeDepartureRepository()..autoReply = const Ok([]),
      )
      ..registerSingleton<FavouritesRepository>(FakeFavouritesRepository())
      ..registerSingleton<WidgetSync>(widgetSync);
  });
  tearDown(getIt.reset);

  group('RuhrTransitApp localization', () {
    testWidgets('falls back to German for an unsupported device locale', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();

      expect(find.text('RuhrTransit'), findsOneWidget);
      expect(find.text('Haltestelle suchen'), findsOneWidget);
      expect(find.textContaining('Alle Angaben ohne Gewähr'), findsOneWidget);
    });

    testWidgets('uses English on an English device', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();

      expect(find.text('Search for a stop'), findsOneWidget);
      expect(
        find.textContaining('All information without guarantee'),
        findsOneWidget,
      );
    });
  });

  group('RuhrTransitApp theme', () {
    testWidgets('uses the dark theme when the system is dark', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(Theme.of(context).useMaterial3, isTrue);
    });
  });

  group('RuhrTransitApp home-screen widget', () {
    testWidgets('a widget launch opens the board above the search', (
      tester,
    ) async {
      await tester.pumpWidget(const RuhrTransitApp(launchedStop: bochumHbf));
      await tester.pumpAndSettle();

      expect(find.byType(DeparturesPage), findsOneWidget);
      expect(find.text('Bochum, Hbf'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(DeparturesPage), findsNothing);
      expect(find.byType(SearchBar), findsOneWidget);
    });

    testWidgets('a widget tap while running opens the board', (tester) async {
      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();
      expect(find.byType(DeparturesPage), findsNothing);

      widgetSync.taps.add(dortmundHbf);
      await tester.pumpAndSettle();

      expect(find.text('Dortmund, Hbf'), findsOneWidget);
    });

    testWidgets('repeated widget taps do not stack boards', (tester) async {
      await tester.pumpWidget(const RuhrTransitApp(launchedStop: bochumHbf));
      await tester.pumpAndSettle();

      widgetSync.taps
        ..add(bochumHbf)
        ..add(bochumHbf);
      await tester.pumpAndSettle();
      expect(find.byType(DeparturesPage), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(SearchBar), findsOneWidget);
    });
  });
}
