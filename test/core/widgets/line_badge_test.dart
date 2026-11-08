import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/network/efa_transport.dart';
import 'package:ruhr_transit/core/widgets/line_badge.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/route_title.dart';

void main() {
  group('readEfaLine', () {
    // Shapes as the service sent them (Berlin to Passau, Rostock to Ulm).
    test('a long-distance train gets its type before the number', () {
      expect(
        readEfaLine({
          'number': '905',
          'name': 'ICE 905 InterCityExpress',
          'properties': {'trainType': 'ICE', 'trainNumber': '905'},
        }),
        'ICE 905',
      );
      expect(
        readEfaLine({
          'number': '1328',
          'properties': {'trainType': 'FLX'},
        }),
        'FLX 1328',
      );
    });

    test('a line that already says what it is stays as it is', () {
      expect(
        readEfaLine({
          'disassembledName': 'RE22',
          'number': 'RE22',
          'properties': {'trainType': 'RE'},
        }),
        'RE22',
      );
      expect(
        readEfaLine({
          'number': 'SEV RE50',
          'properties': {'trainType': 'SEV'},
        }),
        'SEV RE50',
      );
    });

    test('a bus number without a train type stays a number', () {
      expect(readEfaLine({'number': '302'}), '302');
    });
  });

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  group('LineBadge', () {
    testWidgets('writes the vehicle type before the line', (tester) async {
      await pump(tester, const LineBadge('302', mode: TransportMode.bus));
      expect(find.text('Bus 302', findRichText: true), findsOneWidget);
    });

    testWidgets('TalkBack hears the type once', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const LineBadge('U35', mode: TransportMode.subway));
      expect(find.bySemanticsLabel('U-Bahn U35'), findsOneWidget);
      expect(find.bySemanticsLabel('U-Bahn'), findsNothing);
      semantics.dispose();
    });

    testWidgets('without a known type, only the line', (tester) async {
      await pump(tester, const LineBadge('SEV RE50'));
      expect(find.text('SEV RE50', findRichText: true), findsOneWidget);
    });
  });

  group('RouteTitle', () {
    // Two buttons, as on the trip results.
    Future<void> pumpTitle(
      WidgetTester tester,
      double textScale, {
      double width = 411,
    }) async {
      tester.view
        ..physicalSize = Size(width * 3, 2400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Builder(
                builder: (context) => Scaffold(
                  appBar: RouteTitle.appBar(
                    context,
                    from: 'Berlin, S+U Hauptbahnhof',
                    to: 'Passau, Hauptbahnhof',
                    actions: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// Whether [text] is shown in full, not cut off with "…".
    bool whole(WidgetTester tester, String text) => !tester
        .renderObject<RenderParagraph>(find.text(text))
        .didExceedMaxLines;

    for (final width in [360.0, 411.0]) {
      testWidgets('shows both names in full on $width dp', (tester) async {
        await pumpTitle(tester, 1, width: width);
        expect(whole(tester, 'Berlin, S+U Hauptbahnhof'), isTrue);
        expect(whole(tester, '→ Passau, Hauptbahnhof'), isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    for (final scale in [1.0, 2.0]) {
      testWidgets('shows both ends with towns at text ×$scale', (tester) async {
        await pumpTitle(tester, scale);
        expect(find.text('Berlin, S+U Hauptbahnhof'), findsOneWidget);
        expect(find.text('→ Passau, Hauptbahnhof'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('is read as one heading', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTitle(tester, 1);
      expect(
        tester.getSemantics(find.byType(RouteTitle)),
        isSemantics(
          label: 'Berlin, S+U Hauptbahnhof → Passau, Hauptbahnhof',
          isHeader: true,
        ),
      );
      semantics.dispose();
    });
  });
}
