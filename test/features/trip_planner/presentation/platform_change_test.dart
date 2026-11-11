import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_share.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_settings.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_trip_repository.dart';

DateTime _utc(int hour, int minute) => DateTime.utc(2026, 11, 2, hour, minute);

/// The RE1 leaves from platform 4 instead of 3; Dortmund is as planned.
final _moved = Journey([
  TransitLeg(
    line: 'RE1',
    mode: TransportMode.train,
    direction: 'Hamm (Westf) Hbf',
    origin: TripStop(
      name: 'Bochum Hbf',
      plannedTime: _utc(7, 14),
      platform: '4',
      plannedPlatform: '3',
    ),
    destination: TripStop(
      name: 'Dortmund Hbf',
      plannedTime: _utc(7, 26),
      platform: '16',
      plannedPlatform: '16',
    ),
    isRealtime: true,
  ),
]);

const _query = TripQuery(from: bochumHbf, to: dortmundHbf, time: LeaveNow());

Widget _app(Widget home) => MultiBlocProvider(
  providers: [
    BlocProvider(
      create: (_) => FavouriteJourneysCubit(FakeFavouriteJourneysRepository()),
    ),
    BlocProvider(
      create: (_) =>
          ProfileCubit(FakeProfileRepository(), FakeAuthRepository()),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

void main() {
  test('a journey knows where its platforms changed', () {
    expect(_moved.platformChanges.map((stop) => stop.name), ['Bochum Hbf']);
    expect(directS1.platformChanges, isEmpty);
  });

  testWidgets('the results mark the trip, also for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = FakeTripRepository()
      ..replies = [
        Ok([_moved, directS1]),
      ];
    await tester.pumpWidget(
      _app(
        BlocProvider(
          create: (_) => TripResultsCubit(
            repository,
            _query,
            now: () => DateTime.utc(2026, 11, 2, 7),
          )..load(),
          child: const TripResultsView(query: _query),
        ),
      ),
    );
    await tester.pump();

    // Only on the RE1's card.
    expect(find.text('Platform change'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('RE1.*Platform change')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('trip details say so at the top and show the old platform', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(JourneyDetailsPage(journey: _moved, query: _query, runs: null)),
    );

    expect(find.text('Platform change'), findsOneWidget);
    expect(find.text('Platform 4 (was 3)'), findsOneWidget);
    // Unchanged in Dortmund.
    expect(find.text('Platform 16'), findsOneWidget);
  });

  testWidgets('a shared trip names the old platform too', (tester) async {
    late String text;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) {
            text = journeyShareText(context, _moved, query: _query);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(
      text,
      contains('Train RE1 → Hamm (Westf) Hbf, Bochum Hbf, Platform 4 (was 3)'),
    );
  });
}
