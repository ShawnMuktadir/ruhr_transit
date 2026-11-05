import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/home/presentation/home_shell.dart';
import 'package:ruhr_transit/features/language/presentation/locale_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/recent_stops/presentation/recent_stops_cubit.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';
import 'package:ruhr_transit/features/weather/domain/weather_repository.dart';

import '../../helpers/fake_favourite_journeys_repository.dart';
import '../../helpers/fake_favourites_repository.dart';
import '../../helpers/fake_nearby_stops.dart';
import '../../helpers/fake_recent_stops_repository.dart';
import '../../helpers/fake_settings.dart';
import '../../helpers/fake_stop_repository.dart';
import '../../helpers/fake_trip_repository.dart';
import '../../helpers/fake_weather_repository.dart';

void main() {
  late FakeLocationSource location;
  late FakeTripRepository trips;
  late FakeFavouriteJourneysRepository journeys;
  late List<String> platformCalls;

  /// What the app last told Android about Back: true means Back reaches the
  /// app, false means Android 14+ closes it without asking.
  late bool? frameworkHandlesBack;

  setUp(() {
    location = FakeLocationSource();
    trips = FakeTripRepository();
    journeys = FakeFavouriteJourneysRepository();
    getIt
      ..registerFactory<StopRepository>(
        () => FakeStopRepository()..autoReply = const Ok([bochumHbf]),
      )
      ..registerSingleton<LocationSource>(location)
      ..registerFactory<NearbyStopsRepository>(FakeNearbyStopsRepository.new)
      ..registerFactory<TripRepository>(() => trips)
      ..registerFactory<WeatherRepository>(FakeWeatherRepository.new);

    PackageInfo.setMockInitialValues(
      appName: 'RuhrTransit',
      packageName: 'de.muktadir.ruhrtransit',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );

    // Records SystemNavigator.pop, which would close the app.
    platformCalls = [];
    frameworkHandlesBack = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call.method);
          if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
            frameworkHandlesBack = call.arguments as bool;
          }
          return null;
        });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    return getIt.reset();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => FavouritesCubit(FakeFavouritesRepository()),
          ),
          BlocProvider(create: (_) => FavouriteJourneysCubit(journeys)),
          BlocProvider(create: (_) => LocaleCubit(FakeLanguageRepository())),
          BlocProvider(create: (_) => ThemeCubit(FakeThemeRepository())),
          BlocProvider(
            create: (_) => RecentStopsCubit(FakeRecentStopsRepository()),
          ),
          BlocProvider(
            create: (_) =>
                ProfileCubit(FakeProfileRepository(), FakeAuthRepository()),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeShell(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  testWidgets('planning from a stop fills Von and asks for the destination', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Stops near me'));
    await tester.pumpAndSettle();
    final shell = tester.state<HomeShellState>(find.byType(HomeShell));

    shell.planFrom(bochumHbf);
    await tester.pumpAndSettle();

    // The destination picker is open on the planner.
    expect(find.text('Choose destination'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Where to today?'), findsOneWidget);
    expect(find.text('Bochum, Hbf'), findsOneWidget);
  });

  testWidgets('with a destination already chosen, no picker opens', (
    tester,
  ) async {
    await pumpShell(tester);
    final shell = tester.state<HomeShellState>(find.byType(HomeShell));
    shell.planFrom(bochumHbf);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Swapping moves it to "Nach", so a new start leaves it there.
    await tester.tap(find.byTooltip('Swap start and destination'));
    await tester.pump();
    shell.planFrom(dortmundHbf);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Dortmund, Hbf'), findsOneWidget);
    expect(find.text('Bochum, Hbf'), findsOneWidget);
  });

  testWidgets('starts on the planner; only the selected icon is filled', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.text('Where to today?'), findsOneWidget);
    expect(find.byIcon(Icons.directions), findsOneWidget);
    expect(find.byIcon(Icons.directions_outlined), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

    await openTab(tester, 'Settings');
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.directions_outlined), findsOneWidget);
  });

  testWidgets('stops near me starts only when its tab is opened', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(find.byType(NearbyStopsView), findsNothing);

    await openTab(tester, 'Stops near me');

    // The explanation, not the permission dialog.
    expect(find.text('Use my location'), findsOneWidget);
    expect(location.calls, 0);
  });

  testWidgets('each tab keeps its state', (tester) async {
    await pumpShell(tester);
    await openTab(tester, 'Favourites');
    await tester.tap(find.text('Stops'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Boch');

    await openTab(tester, 'Settings');
    await openTab(tester, 'Favourites');

    expect(find.widgetWithText(TextField, 'Boch'), findsOneWidget);
  });

  testWidgets('Back goes back in the tab, then to the planner, then out', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Choose start'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await back(tester);
    expect(find.byType(TextField), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await openTab(tester, 'Settings');
    await back(tester);
    expect(find.text('Where to today?'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));

    await back(tester);
    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('tells Android when Back stays in the app', (tester) async {
    // WidgetsApp only reports while the app is in the foreground.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpShell(tester);
    expect(frameworkHandlesBack, isFalse);

    // A tab at its start must not report "nothing to go back to": Back
    // switches to the planner.
    await openTab(tester, 'Stops near me');
    expect(frameworkHandlesBack, isTrue);
    await openTab(tester, 'Settings');
    expect(frameworkHandlesBack, isTrue);

    await openTab(tester, 'Plan trip');
    expect(frameworkHandlesBack, isFalse);
    await tester.tap(find.text('Choose start'));
    await tester.pumpAndSettle();
    expect(frameworkHandlesBack, isTrue);

    await back(tester);
    expect(frameworkHandlesBack, isFalse);
  });

  bool fieldHasFocus(WidgetTester tester) =>
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus;

  testWidgets('a tab gets its focused field back when it returns', (
    tester,
  ) async {
    await pumpShell(tester);
    await tester.tap(find.text('Choose start'));
    await tester.pumpAndSettle();
    expect(fieldHasFocus(tester), isTrue);

    // Leaving the tab closes its keyboard ...
    await openTab(tester, 'Settings');
    expect(tester.testTextInput.isVisible, isFalse);

    // ... coming back opens it again, ready to type.
    await openTab(tester, 'Plan trip');
    expect(fieldHasFocus(tester), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('tapping the open tab returns to its start', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Choose start'));
    await tester.pumpAndSettle();

    await openTab(tester, 'Plan trip');

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Where to today?'), findsOneWidget);
  });

  testWidgets('a saved journey fills in the planner and searches', (
    tester,
  ) async {
    journeys.saved = [
      FavouriteJourney(
        from: bochumHbf,
        to: dortmundHbf,
        savedAt: DateTime.utc(2026, 11, 2),
      ),
    ];
    await pumpShell(tester);
    await openTab(tester, 'Favourites');

    await tester.tap(find.text('Bochum, Hbf → Dortmund, Hbf'));
    await tester.pumpAndSettle();

    expect(find.byType(TripResultsView), findsOneWidget);
    expect(trips.queries.single.from, bochumHbf);
    expect(trips.queries.single.to, dortmundHbf);
    expect(trips.queries.single.time, isA<LeaveNow>());

    await back(tester);
    expect(find.text('Bochum, Hbf'), findsOneWidget);
    expect(find.text('Dortmund, Hbf'), findsOneWidget);
    // The planner's bookmark shows the journey is saved.
    expect(find.byTooltip('Remove saved journey'), findsOneWidget);
  });
}
