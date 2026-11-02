import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_chip.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_cubit.dart';

import '../../../helpers/fake_nearby_stops.dart';
import '../../../helpers/fake_weather_repository.dart';

void main() {
  late FakeLocationSource location;
  late FakeWeatherRepository weather;
  late DateTime now;

  setUp(() {
    location = FakeLocationSource();
    weather = FakeWeatherRepository();
    now = DateTime.utc(2026, 11, 2, 19);
  });

  WeatherCubit cubit() => WeatherCubit(weather, location, now: () => now);

  group('WeatherCubit', () {
    test('never asks for the location by itself', () async {
      final weatherCubit = cubit();
      await weatherCubit.load();

      expect(weatherCubit.state, isA<WeatherNeedsPermission>());
      expect(location.calls, 0);
      expect(weather.points, isEmpty);
    });

    test('with permission, shows the weather where the user is', () async {
      location.permissionGranted = true;
      final weatherCubit = cubit();
      await weatherCubit.load();

      expect(
        weatherCubit.state,
        isA<WeatherShown>().having((s) => s.fetchedAt, 'fetchedAt', now),
      );
      expect(weather.points, [
        (bochumHbfLocation.latitude, bochumHbfLocation.longitude),
      ]);
    });

    test('a tap asks for the permission, then shows the weather', () async {
      final weatherCubit = cubit();
      await weatherCubit.load();

      await weatherCubit.tap();

      expect(location.calls, 1);
      expect(weatherCubit.state, isA<WeatherShown>());
    });

    test('denied for good: a tap opens the app settings, the return '
        'loads without asking', () async {
      location.result = const LocationPermissionDenied(permanently: true);
      final weatherCubit = cubit();
      await weatherCubit.load();
      await weatherCubit.tap();
      expect(
        weatherCubit.state,
        isA<WeatherNeedsPermission>().having(
          (s) => s.permanently,
          'permanently',
          isTrue,
        ),
      );

      await weatherCubit.tap();
      expect(location.appSettingsOpened, 1);

      // Allowed in the settings.
      location
        ..permissionGranted = true
        ..result = bochumHbfLocation;
      await weatherCubit.resumed();
      expect(weatherCubit.state, isA<WeatherShown>());
    });

    test('location off: a tap opens the location settings', () async {
      location
        ..permissionGranted = true
        ..result = const LocationOff();
      final weatherCubit = cubit();
      await weatherCubit.load();
      expect(weatherCubit.state, isA<WeatherLocationOff>());

      await weatherCubit.tap();
      expect(location.locationSettingsOpened, 1);

      location.result = bochumHbfLocation;
      await weatherCubit.resumed();
      expect(weatherCubit.state, isA<WeatherShown>());
    });

    test('coming back without permission does not ask again', () async {
      final weatherCubit = cubit();
      await weatherCubit.load();

      await weatherCubit.resumed();

      expect(location.calls, 0);
      expect(weatherCubit.state, isA<WeatherNeedsPermission>());
    });

    test('fetches again on return only after 30 minutes', () async {
      location.permissionGranted = true;
      final weatherCubit = cubit();
      await weatherCubit.load();

      now = now.add(const Duration(minutes: 29));
      await weatherCubit.resumed();
      expect(weather.points, hasLength(1));

      now = now.add(const Duration(minutes: 1));
      await weatherCubit.resumed();
      expect(weather.points, hasLength(2));
    });

    test('names what went wrong', () async {
      location.permissionGranted = true;
      final cases = {
        const NetworkFailure(): WeatherProblem.offline,
        const TimeoutFailure(): WeatherProblem.offline,
        const ServerFailure(code: 404): WeatherProblem.notHere,
        const ServerFailure(code: 500): WeatherProblem.failed,
        const ParseFailure('x'): WeatherProblem.failed,
      };
      for (final MapEntry(key: failure, value: problem) in cases.entries) {
        weather.reply = Err(failure);
        final weatherCubit = cubit();
        await weatherCubit.load();
        expect(
          weatherCubit.state,
          isA<WeatherUnavailable>().having(
            (s) => s.problem,
            '$failure',
            problem,
          ),
        );
      }

      weather.reply = Ok(cloudyWithRain);
      location.result = const LocationTimeout();
      final weatherCubit = cubit();
      await weatherCubit.load();
      expect(
        weatherCubit.state,
        isA<WeatherUnavailable>().having(
          (s) => s.problem,
          'problem',
          WeatherProblem.noPosition,
        ),
      );

      // A tap retries.
      location.result = bochumHbfLocation;
      await weatherCubit.tap();
      expect(weatherCubit.state, isA<WeatherShown>());
    });
  });

  group('WeatherChip', () {
    Future<WeatherCubit> pump(WidgetTester tester, {String lang = 'en'}) async {
      final weatherCubit = cubit();
      final loaded = weatherCubit.load();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
          home: Scaffold(
            body: BlocProvider.value(
              value: weatherCubit,
              child: const WeatherChip(),
            ),
          ),
        ),
      );
      await tester.runAsync(() => loaded);
      await tester.pump();
      return weatherCubit;
    }

    String localTime(DateTime utc) {
      final local = utc.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(local.hour)}:${two(local.minute)}';
    }

    testWidgets('shows temperature, sky, rain hint and the source', (
      tester,
    ) async {
      location.permissionGranted = true;
      await pump(tester);

      expect(find.text('9 °C · Cloudy'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
      expect(
        find.text(
          'Rain from ${localTime(cloudyWithRain.precipitation!.startsAt)} '
          '– take an umbrella',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Deutscher Wetterdienst'), findsOneWidget);
    });

    testWidgets('in German, snow falling now', (tester) async {
      location.permissionGranted = true;
      weather.reply = Ok(
        Weather(
          sky: WeatherSky.snow,
          temperature: -0.3,
          observedAt: now,
          precipitation: PrecipitationOutlook(
            kind: PrecipitationKind.snow,
            startsAt: now,
            isNow: true,
          ),
        ),
      );
      await pump(tester, lang: 'de');

      // Not "-0 °C".
      expect(find.text('0 °C · Schnee'), findsOneWidget);
      expect(find.text('Es schneit – warm anziehen'), findsOneWidget);
    });

    testWidgets('asks for the location on tap', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      expect(find.text('Weather not available – allow location'), findsOne);
      expect(find.textContaining('Deutscher Wetterdienst'), findsNothing);
      expect(
        tester.getSemantics(
          find.text('Weather not available – allow location'),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );

      await tester.tap(find.text('Weather not available – allow location'));
      await tester.pump();
      await tester.pump();

      expect(location.calls, 1);
      expect(find.text('9 °C · Cloudy'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('location off and offline say so', (tester) async {
      location
        ..permissionGranted = true
        ..result = const LocationOff();
      final weatherCubit = await pump(tester);
      expect(
        find.text('Weather not available – turn on location services'),
        findsOneWidget,
      );

      location.result = bochumHbfLocation;
      weather.reply = const Err(NetworkFailure());
      await weatherCubit.load();
      await tester.pump();
      expect(find.text('Weather offline – tap to retry'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
    });

    testWidgets('loads again when the app comes back from the settings', (
      tester,
    ) async {
      location.result = const LocationPermissionDenied(permanently: true);
      final weatherCubit = await pump(tester);
      await weatherCubit.tap();
      await tester.pump();
      await tester.tap(find.text('Weather not available – allow location'));
      await tester.pump();
      expect(location.appSettingsOpened, 1);

      location
        ..permissionGranted = true
        ..result = bochumHbfLocation;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();

      expect(find.text('9 °C · Cloudy'), findsOneWidget);
    });
  });
}
