import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';
import 'package:ruhr_transit/core/widgets/platform_chip.dart';

void main() {
  Future<void> pumpChip(
    WidgetTester tester,
    PlatformChip chip, {
    String locale = 'en',
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme ?? AppTheme.light,
        home: Scaffold(body: Center(child: chip)),
      ),
    );
    // A new theme animates in.
    await tester.pumpAndSettle();
  }

  Text chipText(WidgetTester tester) => tester.widget<Text>(
    find.descendant(of: find.byType(PlatformChip), matching: find.byType(Text)),
  );

  BoxDecoration chipDecoration(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byType(PlatformChip),
                  matching: find.byType(Container),
                ),
              )
              .decoration!
          as BoxDecoration;

  group('PlatformChip', () {
    testWidgets('labels a bare number in English', (tester) async {
      await pumpChip(tester, const PlatformChip(platform: '5'));

      expect(find.text('Platform 5'), findsOneWidget);
      expect(chipText(tester).style?.fontWeight, FontWeight.bold);
    });

    testWidgets('labels a bare number in German', (tester) async {
      await pumpChip(tester, const PlatformChip(platform: '5'), locale: 'de');

      expect(find.text('Gleis 5'), findsOneWidget);
    });

    testWidgets('keeps letters that belong to the number', (tester) async {
      await pumpChip(tester, const PlatformChip(platform: '7 A-D'));

      expect(find.text('Platform 7 A-D'), findsOneWidget);
    });

    testWidgets('a bus stops at a bay, not a platform', (tester) async {
      await pumpChip(
        tester,
        const PlatformChip(platform: '03', mode: TransportMode.bus),
        locale: 'de',
      );

      expect(find.text('Steig 03'), findsOneWidget);
    });

    testWidgets('shows values that name themselves as they are', (
      tester,
    ) async {
      // All seen in live VRR responses.
      for (final value in ['Gleis 2 (U)', 'U-Bahn Gleis 2', 'Steig 1', 'Bus']) {
        await pumpChip(tester, PlatformChip(platform: value), locale: 'de');
        expect(find.text(value), findsOneWidget, reason: value);
      }
    });

    testWidgets('shows nothing without a platform', (tester) async {
      for (final value in [null, '', '  ']) {
        await pumpChip(tester, PlatformChip(platform: value));
        expect(find.byType(Text), findsNothing, reason: '"$value"');
        expect(find.byType(Container), findsNothing, reason: '"$value"');
      }
    });

    testWidgets('fills with the secondary container colours', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await pumpChip(tester, const PlatformChip(platform: '5'), theme: theme);
        expect(
          chipDecoration(tester).color,
          theme.colorScheme.secondaryContainer,
        );
        expect(
          chipText(tester).style?.color,
          theme.colorScheme.onSecondaryContainer,
        );
      }
    });

    testWidgets('marks a changed platform with the old one, in two languages', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const chip = PlatformChip(platform: '2', plannedPlatform: '1');

      await pumpChip(tester, chip);
      expect(find.text('Platform 2 (was 1)'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Platform change: Platform 2 instead of 1'),
        findsOneWidget,
      );
      expect(
        chipDecoration(tester).color,
        AppTheme.light.colorScheme.errorContainer,
      );

      await pumpChip(tester, chip, locale: 'de');
      expect(find.text('Gleis 2 (statt 1)'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Gleiswechsel: Gleis 2 statt 1'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('the same platform as planned is not a change', (tester) async {
      await pumpChip(
        tester,
        const PlatformChip(platform: '5', plannedPlatform: '5'),
      );

      expect(find.text('Platform 5'), findsOneWidget);
      expect(
        chipDecoration(tester).color,
        AppTheme.light.colorScheme.secondaryContainer,
      );
    });
  });
}
