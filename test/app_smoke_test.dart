import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/app.dart';

void main() {
  group('RuhrTransitApp localization', () {
    testWidgets('falls back to German for an unsupported device locale', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();

      expect(find.text('RuhrTransit'), findsOneWidget);
      expect(
        find.text('Haltestellensuche und Abfahrten folgen in Kürze.'),
        findsOneWidget,
      );
      expect(find.textContaining('Alle Angaben ohne Gewähr'), findsOneWidget);
    });

    testWidgets('uses English on an English device', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('en', 'GB')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await tester.pumpWidget(const RuhrTransitApp());
      await tester.pumpAndSettle();

      expect(
        find.text('Stop search and departures are coming soon.'),
        findsOneWidget,
      );
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
