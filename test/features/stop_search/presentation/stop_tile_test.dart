import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_tile.dart';

void main() {
  testWidgets(
    'a station with every mode leaves the text the width of the row',
    (tester) async {
      const station = Stop(
        id: 'de:05911:5194',
        name: 'Hbf',
        fullName: 'Bochum, Hbf',
        latitude: 51.479561,
        longitude: 7.221691,
        locality: 'Bochum',
        modes: {...TransportMode.values},
      );
      // A 1080 × 2400 phone, like the emulator.
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StopTile(
              station,
              detail: '140 m away',
              action: IconButton(
                icon: const Icon(Icons.star),
                onPressed: () {},
              ),
              below: const Text('310 in 1 min · RE41 in 2 min'),
            ),
          ),
        ),
      );

      // Phone width: the icons used to sit beside the text and squeeze it
      // into a third of the row.
      double widthFor(String text) => tester
          .renderObject<RenderParagraph>(find.text(text))
          .constraints
          .maxWidth;
      expect(widthFor('Bochum · 140 m away'), greaterThan(220));
      expect(widthFor('310 in 1 min · RE41 in 2 min'), greaterThan(220));
      expect(find.byIcon(Icons.train), findsOneWidget);
    },
  );
}
