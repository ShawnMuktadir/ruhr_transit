import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/greeting_header.dart';

void main() {
  // Local times: the greeting follows the phone's clock.
  DateTime at(int hour, [int minute = 0, int second = 0]) =>
      DateTime(2026, 11, 2, hour, minute, second);

  group('GreetingTime', () {
    test('changes at 05, 11, 18 and 22 o\'clock', () {
      expect(GreetingTime.at(at(4, 59)), GreetingTime.night);
      expect(GreetingTime.at(at(5)), GreetingTime.morning);
      expect(GreetingTime.at(at(10, 59)), GreetingTime.morning);
      expect(GreetingTime.at(at(11)), GreetingTime.afternoon);
      expect(GreetingTime.at(at(17, 59)), GreetingTime.afternoon);
      expect(GreetingTime.at(at(18)), GreetingTime.evening);
      expect(GreetingTime.at(at(21, 59)), GreetingTime.evening);
      expect(GreetingTime.at(at(22)), GreetingTime.night);
      expect(GreetingTime.at(at(0)), GreetingTime.night);
    });

    test('knows when the next period begins', () {
      expect(GreetingTime.nextChange(at(7, 30)), at(11));
      expect(GreetingTime.nextChange(at(11)), at(18));
      expect(GreetingTime.nextChange(at(21, 59)), at(22));
      expect(GreetingTime.nextChange(at(3)), at(5));
      expect(GreetingTime.nextChange(at(23)), DateTime(2026, 11, 3, 5));
    });
  });

  group('GreetingHeader', () {
    Future<void> pump(
      WidgetTester tester, {
      required DateTime Function() now,
      String? name,
      Locale locale = const Locale('en'),
    }) => tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GreetingHeader(displayName: name, now: now),
        ),
      ),
    );

    testWidgets('greets by the time of day, with the name if there is one', (
      tester,
    ) async {
      await pump(tester, now: () => at(8), name: 'Shawn');
      expect(find.text('Good morning, Shawn'), findsOneWidget);
      expect(find.text('Where to today?'), findsOneWidget);

      await pump(tester, now: () => at(23));
      // Another clock and no name.
      expect(find.text('Good night'), findsOneWidget);
    });

    testWidgets('speaks the app language', (tester) async {
      for (final (hour, greeting) in [
        (6, 'Guten Morgen'),
        (14, 'Guten Tag'),
        (19, 'Guten Abend'),
        (2, 'Gute Nacht'),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await pump(tester, now: () => at(hour), locale: const Locale('de'));
        expect(find.text(greeting), findsOneWidget);
      }
      expect(find.text('Wohin geht’s heute?'), findsOneWidget);
    });

    testWidgets('switches greeting when the period changes while open', (
      tester,
    ) async {
      var now = at(10, 59, 30);
      await pump(tester, now: () => now);
      expect(find.text('Good morning'), findsOneWidget);

      now = at(11, 0, 1);
      await tester.pump(const Duration(seconds: 31));

      expect(find.text('Good afternoon'), findsOneWidget);
    });

    testWidgets('the greeting is a heading for TalkBack', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, now: () => at(19), name: 'Shawn');

      expect(
        tester.getSemantics(find.text('Good evening, Shawn')),
        isSemantics(isHeader: true, label: 'Good evening, Shawn'),
      );
      semantics.dispose();
    });
  });
}
