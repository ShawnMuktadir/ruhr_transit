import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/platform/share.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vrr_trip_link.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_share.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_settings.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_trip_repository.dart';

const _query = TripQuery(from: bochumHbf, to: dortmundHbf, time: LeaveNow());

/// [utc] as the phone shows it in 24-hour format.
String _clock(DateTime utc) {
  final local = utc.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

Widget _app(Widget home, {Locale locale = const Locale('en')}) =>
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
        ),
        BlocProvider(
          create: (_) =>
              ProfileCubit(FakeProfileRepository(), FakeAuthRepository()),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: home,
      ),
    );

void main() {
  group('vrrTripLink', () {
    test('stops by their ID, at the local departure time', () {
      final link = vrrTripLink(
        from: bochumHbf,
        to: dortmundHbf,
        departure: DateTime(2026, 11, 11, 13, 7),
        languageCode: 'de',
      );

      expect(link.host, 'efa.vrr.de');
      expect(link.path, '/vrr/XSLT_TRIP_REQUEST2');
      expect(link.queryParameters, {
        'language': 'de',
        'sessionID': '0',
        'type_origin': 'stop',
        'name_origin': 'de:05911:5194',
        'type_destination': 'stop',
        'name_destination': 'de:05913:131',
        'itdDate': '20261111',
        'itdTime': '1307',
        'itdTripDateTimeDepArr': 'dep',
      });
    });

    test('an address by its coordinates, longitude first', () {
      final link = vrrTripLink(
        from: kortumstr10,
        to: dortmundHbf,
        departure: DateTime(2026, 11, 11, 9),
        languageCode: 'en',
      );

      expect(link.queryParameters['type_origin'], 'coord');
      expect(
        link.queryParameters['name_origin'],
        '${kortumstr10.longitude.toStringAsFixed(5)}:'
        '${kortumstr10.latitude.toStringAsFixed(5)}:WGS84[dd.ddddd]',
      );
    });
  });

  group('journeyShareText', () {
    Future<String> textOf(
      WidgetTester tester,
      Journey journey, {
      TripQuery? query,
      Locale locale = const Locale('en'),
    }) async {
      late String text;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              text = journeyShareText(context, journey, query: query);
              return const SizedBox();
            },
          ),
          locale: locale,
        ),
      );
      return text;
    }

    testWidgets('a direct ride with delays and the VRR link', (tester) async {
      final text = await textOf(tester, directS1, query: _query);
      final ride = directS1.legs.single as TransitLeg;
      final departs = '${_clock(ride.origin.plannedTime)} (3 min late)';
      final arrives = '${_clock(ride.destination.plannedTime)} (2 min late)';
      final lines = text.split('\n');

      expect(lines[0], 'Bochum, Hbf → Dortmund, Hbf');
      expect(lines[1], endsWith(' · $departs → $arrives · 22 min · Direct'));
      expect(lines[2], '');
      expect(
        lines[3],
        '$departs  S-Bahn S1 → Dortmund Hbf, Bochum Hbf, Platform 8',
      );
      expect(lines[4], '$arrives  Arrive at Dortmund Hbf');
      expect(lines[6], "Live in VRR's journey planner:");
      final link = Uri.parse(lines[7]);
      expect(link.queryParameters['name_origin'], 'de:05911:5194');
      expect(
        link.queryParameters['itdTime'],
        _clock(ride.origin.plannedTime).replaceAll(':', ''),
      );
      expect(lines.last, 'Shared from RuhrTransit');
    });

    testWidgets('rides, a walk and a change, in German', (tester) async {
      final text = await textOf(tester, withWalk, locale: const Locale('de'));
      final [first, walk, bus] = withWalk.legs;

      expect(text, contains('U-Bahn U35 → Herne Schloß Strünkede'));
      expect(
        text,
        contains(
          '${_clock(walk.origin.plannedTime)}  4 Min. Fußweg → '
          'Bochum Hbf/Boulevard',
        ),
      );
      expect(text, contains('Bus 339 → Bochum Ruhr-Universität'));
      expect(text, contains('1 Umstieg'));
      expect(
        text,
        contains(
          '${_clock(bus.destination.plannedTime)}  '
          'Ankunft Bochum BP/Aral-Haus',
        ),
      );
      expect(text, contains(first.origin.name));
      // Without the searched stops there is no link.
      expect(text, isNot(contains('efa.vrr.de')));
      expect(text, endsWith('Geteilt aus RuhrTransit'));
    });
  });

  group('copy and share', () {
    late List<MethodCall> shared;
    // Android 13+ shows copied text itself.
    late bool systemConfirms;

    setUp(() {
      shared = [];
      systemConfirms = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, (call) async {
            if (call.method == 'systemConfirmsCopy') return systemConfirms;
            shared.add(call);
            return null;
          });
    });
    tearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(shareChannel, null),
    );

    Future<void> pumpResults(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(
          BlocProvider(
            create: (_) => TripResultsCubit(
              FakeTripRepository(),
              _query,
              now: () => DateTime.utc(2026, 11, 2, 7),
            )..load(),
            child: const TripResultsView(query: _query),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('long-press a trip, then copy it', (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpResults(tester);

      await tester.longPress(find.textContaining('22 min').first);
      await tester.pumpAndSettle();
      expect(find.text('Share trip'), findsOneWidget);

      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(copied, startsWith('Bochum, Hbf → Dortmund, Hbf\n'));
      expect(copied, contains('S-Bahn S1'));
      expect(find.text('Trip copied'), findsOneWidget);
    });

    testWidgets('where Android shows the copy, the app adds nothing', (
      tester,
    ) async {
      systemConfirms = true;
      await pumpResults(tester);

      await tester.longPress(find.textContaining('22 min').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      expect(find.text('Share trip'), findsNothing);
      expect(find.text('Trip copied'), findsNothing);
    });

    testWidgets('long-press a trip, then share it', (tester) async {
      await pumpResults(tester);

      await tester.longPress(find.textContaining('22 min').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share…'));
      await tester.pumpAndSettle();

      final call = shared.single;
      expect(call.method, 'text');
      final arguments = call.arguments as Map;
      expect(arguments['subject'], 'Bochum, Hbf → Dortmund, Hbf');
      expect(arguments['text'], contains('efa.vrr.de'));
      expect(find.text('Share trip'), findsNothing);
    });

    testWidgets('screen readers hear what a long press does', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpResults(tester);

      expect(
        tester.getSemantics(find.textContaining('22 min').first),
        isSemantics(
          hasTapAction: true,
          hasLongPressAction: true,
          onLongPressHint: 'Share or copy',
        ),
      );
      semantics.dispose();
    });

    testWidgets('trip details share from the app bar', (tester) async {
      await tester.pumpWidget(
        _app(JourneyDetailsPage(journey: directS1, query: _query, runs: null)),
      );

      await tester.tap(find.byTooltip('Share trip'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share…'));
      await tester.pumpAndSettle();

      expect(
        (shared.single.arguments as Map)['text'],
        startsWith('Bochum, Hbf → Dortmund, Hbf\n'),
      );
    });
  });
}
