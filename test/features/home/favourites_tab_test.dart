import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/home/presentation/favourites_tab.dart';

import '../../helpers/fake_favourite_journeys_repository.dart';

void main() {
  late ValueNotifier<FavouritesSegment> segment;

  setUp(() => segment = ValueNotifier(FavouritesSegment.journeys));
  tearDown(() => segment.dispose());

  Future<void> pumpTab(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) =>
            FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
        child: MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: FavouritesTab(
            segment: segment,
            onOpenJourney: (_) {},
            stops: const Text('stops segment'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('journeys first, stops one tap away', (tester) async {
    await pumpTab(tester);
    expect(find.textContaining('Noch keine Verbindungen'), findsOneWidget);

    await tester.tap(find.text('Haltestellen'));
    await tester.pumpAndSettle();

    expect(segment.value, FavouritesSegment.stops);
    expect(find.text('stops segment'), findsOneWidget);
  });

  testWidgets('segments show icons at normal text', (tester) async {
    await pumpTab(tester);

    expect(find.byIcon(Icons.bookmark_border), findsWidgets);
  });

  testWidgets('from 1.3x text the icons make room, labels stay one line', (
    tester,
  ) async {
    await pumpTab(tester, textScale: 2);

    final segments = find.byType(SegmentedButton<FavouritesSegment>);
    expect(
      find.descendant(of: segments, matching: find.byType(Icon)),
      findsNothing,
    );
    final label = tester.widget<Text>(
      find.descendant(of: segments, matching: find.text('Verbindungen')),
    );
    expect(label.maxLines, 1);
  });
}
