import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_means.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_means_filter.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_settings.dart';
import '../../../helpers/fake_stop_repository.dart';
import '../../../helpers/fake_trip_repository.dart';

const _query = TripQuery(from: bochumHbf, to: dortmundHbf, time: LeaveNow());

void main() {
  late ExcludedMeansCubit means;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    means = ExcludedMeansCubit(SharedPreferencesAsync());
  });
  tearDown(() => means.close());

  Widget app(Widget home) => MultiBlocProvider(
    providers: [
      BlocProvider.value(value: means),
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
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  group('ExcludedMeansCubit', () {
    test('turns means off and on, and saves them', () async {
      await means.toggle(TripMeans.ice);
      await means.toggle(TripMeans.bus);
      await means.toggle(TripMeans.bus);
      expect(means.state, {TripMeans.ice});

      final later = ExcludedMeansCubit(SharedPreferencesAsync());
      addTearDown(later.close);
      await Future<void>.delayed(Duration.zero);
      expect(later.state, {TripMeans.ice});
    });

    test('the last means that is on stays on', () async {
      for (final m in TripMeans.values) {
        await means.toggle(m);
      }
      expect(means.state, hasLength(TripMeans.values.length - 1));
      expect(means.state, isNot(contains(TripMeans.other)));
    });
  });

  testWidgets('the trip form has a chip per means of transport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1080, 4000)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app(
        BlocProvider(
          create: (_) => TripFormCubit(),
          child: TripFormView(
            pickStop: (context, {required title}) async => null,
          ),
        ),
      ),
    );

    expect(find.byType(FilterChip), findsNWidgets(TripMeans.values.length));
    for (final label in [
      'Regional train',
      'S-Bahn',
      'U-Bahn',
      'Tram',
      'Bus',
      'ICE',
      'IC/EC',
      'Others',
    ]) {
      expect(find.widgetWithText(FilterChip, label), findsOneWidget);
    }

    await tester.tap(find.widgetWithText(FilterChip, 'ICE'));
    await tester.pump();
    expect(means.state, {TripMeans.ice});
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'ICE'))
          .selected,
      isFalse,
    );
  });

  group('trip results', () {
    late FakeTripRepository repository;

    setUp(() {
      repository = FakeTripRepository();
      getIt.registerFactory<TripRepository>(() => repository);
    });
    tearDown(getIt.reset);

    testWidgets('search without what is off, and say so', (tester) async {
      await means.toggle(TripMeans.ice);
      await tester.pumpWidget(app(const TripResultsPage(query: _query)));
      await tester.pump();

      expect(repository.queries.first.excluded, {TripMeans.ice});
      expect(find.text('Without ICE'), findsOneWidget);
    });

    testWidgets('a change in the filter sheet searches again', (tester) async {
      await tester.pumpWidget(app(const TripResultsPage(query: _query)));
      await tester.pump();
      expect(find.textContaining('Without'), findsNothing);

      await tester.tap(find.byTooltip('Choose means of transport'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Bus'));
      await tester.pumpAndSettle();

      expect(repository.queries.last.excluded, {TripMeans.bus});
      expect(find.text('Without Bus'), findsOneWidget);
    });
  });
}
