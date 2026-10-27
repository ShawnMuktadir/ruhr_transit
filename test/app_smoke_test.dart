import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/app.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';

import 'helpers/fake_stop_repository.dart';

void main() {
  // The real app resolves the repository through get_it; a fake keeps the
  // smoke tests off the network.
  setUp(() => getIt.registerFactory<StopRepository>(FakeStopRepository.new));
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
}
