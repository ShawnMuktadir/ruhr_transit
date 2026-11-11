import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/platform/open_link.dart';
import 'package:ruhr_transit/core/widgets/translate.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_notices.dart';

import '../../helpers/fake_departure_repository.dart';
import '../../helpers/fake_favourites_repository.dart';
import '../../helpers/fake_stop_repository.dart';
import '../../helpers/fake_trip_repository.dart';

void main() {
  late List<String> opened;
  // What the platform answers: whether something opened the link.
  late bool opens;

  setUp(() {
    opened = [];
    opens = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(linksChannel, (call) async {
          opened.add((call.arguments as Map)['url'] as String);
          return opens;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(linksChannel, null),
  );

  Widget app(Widget home, {String locale = 'en'}) => BlocProvider(
    create: (_) => FavouritesCubit(FakeFavouritesRepository()),
    child: MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  test('the link goes from German to the app language, at most 5000 chars', () {
    final link = Translate.link('Umleitung', languageCode: 'en');
    expect(link.host, 'translate.google.com');
    expect(link.queryParameters, {
      'sl': 'de',
      'tl': 'en',
      'text': 'Umleitung',
      'op': 'translate',
    });
    expect(
      Translate.link('x' * 6000, languageCode: 'en').queryParameters['text'],
      hasLength(Translate.maxLength),
    );
  });

  testWidgets('the button opens the text, and says when nothing could', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const Scaffold(body: TranslateButton('Umleitung wegen Baustelle'))),
    );

    await tester.tap(find.text('Translate'));
    await tester.pump();
    expect(
      Uri.parse(opened.single).queryParameters['text'],
      'Umleitung wegen Baustelle',
    );
    expect(find.text('Could not open the translation.'), findsNothing);

    opens = false;
    await tester.tap(find.text('Translate'));
    await tester.pump();
    expect(find.text('Could not open the translation.'), findsOneWidget);
  });

  testWidgets('nothing to offer when the app is in German', (tester) async {
    await tester.pumpWidget(
      app(
        const Scaffold(body: TranslateButton('Umleitung wegen Baustelle')),
        locale: 'de',
      ),
    );
    expect(find.byType(TextButton), findsNothing);
    expect(find.text('Übersetzen'), findsNothing);
  });

  testWidgets('a notice translates its title and text', (tester) async {
    await tester.pumpWidget(
      app(
        const Scaffold(
          body: SingleChildScrollView(child: TripNoticesSection([liftNotice])),
        ),
      ),
    );
    // The section starts collapsed.
    await tester.tap(find.text('1 notice'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(liftNotice.title));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Translate'));
    await tester.pump();

    expect(
      Uri.parse(opened.single).queryParameters['text'],
      '${liftNotice.title}\n\n${liftNotice.text}',
    );
  });

  testWidgets('a ride translates its notes', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 6000)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(JourneyDetailsPage(journey: withWalk, runs: null)),
    );

    await tester.tap(find.text('Translate'));
    await tester.pump();
    expect(
      Uri.parse(opened.single).queryParameters['text'],
      'Umleitung wegen Baustelle',
    );
  });

  testWidgets('a board row with a reason: button and screen reader action', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = FakeDepartureRepository()
      ..autoReply = Ok([delayedRe16, cancelledRe11]);
    await tester.pumpWidget(
      app(
        BlocProvider(
          create: (_) =>
              DeparturesCubit(repository, bochumHbf.id, now: () => boardTime)
                ..load(),
          child: const DeparturesView(stop: bochumHbf),
        ),
      ),
    );
    await tester.pump();

    // Only the RE16 has a reason from VRR.
    expect(find.text('Translate'), findsOneWidget);
    expect(
      tester.getSemantics(find.textContaining('RE16', findRichText: true)),
      isSemantics(
        customActions: [const CustomSemanticsAction(label: 'Translate')],
      ),
    );

    await tester.tap(find.text('Translate'));
    await tester.pump();
    expect(
      Uri.parse(opened.single).queryParameters['text'],
      'Vorfahrt eines anderen Zuges',
    );
    semantics.dispose();
  });
}
