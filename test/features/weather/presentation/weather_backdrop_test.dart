import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/theme/app_theme.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_backdrop.dart';
import 'package:ruhr_transit/features/weather/presentation/weather_cubit.dart';

import '../../../helpers/fake_favourite_journeys_repository.dart';
import '../../../helpers/fake_nearby_stops.dart';
import '../../../helpers/fake_settings.dart';
import '../../../helpers/fake_weather_repository.dart';

/// The WCAG contrast of two opaque colours, from 1 to 21.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

const _from = Stop(
  id: 'a',
  name: 'Bochum Hbf',
  fullName: 'Bochum Hbf',
  latitude: 51.47,
  longitude: 7.22,
);
const _to = Stop(
  id: 'b',
  name: 'Essen Hbf',
  fullName: 'Essen Hbf',
  latitude: 51.45,
  longitude: 7.01,
);

void main() {
  group('WeatherLook', () {
    final shown = WeatherSky.values.where((sky) => sky != WeatherSky.unknown);

    test('the page stays normal without a known sky', () {
      for (final brightness in Brightness.values) {
        expect(WeatherLook.of(null, brightness), isNull);
        expect(WeatherLook.of(WeatherSky.unknown, brightness), isNull);
      }
    });

    test('every other sky has a look in both themes', () {
      for (final brightness in Brightness.values) {
        for (final sky in shown) {
          expect(WeatherLook.of(sky, brightness), isNotNull, reason: '$sky');
        }
      }
    });

    test('text is readable on every part of every sky', () {
      for (final brightness in Brightness.values) {
        for (final sky in shown) {
          final look = WeatherLook.of(sky, brightness)!;
          for (final background in look.backgrounds) {
            for (final text in [look.foreground, look.secondary]) {
              expect(
                _contrast(text, background),
                greaterThanOrEqualTo(4.5),
                reason: '$sky in $brightness: $text on $background',
              );
            }
          }
        }
      }
    });

    test('app bar icons are black on a light sky, white on a dark one', () {
      for (final brightness in Brightness.values) {
        for (final sky in shown) {
          final look = WeatherLook.of(sky, brightness)!;
          expect(
            look.icon,
            look.isDark ? Colors.white : Colors.black,
            reason: '$sky in $brightness',
          );
          for (final background in [look.top, look.bottom]) {
            expect(
              _contrast(look.icon, background),
              greaterThanOrEqualTo(3),
              reason: '$sky in $brightness on $background',
            );
          }
        }
      }
    });

    test('status bar icons follow the sky', () {
      expect(
        WeatherLook.of(WeatherSky.clearNight, Brightness.light)!.isDark,
        isTrue,
      );
      expect(
        WeatherLook.of(WeatherSky.snow, Brightness.light)!.isDark,
        isFalse,
      );
      expect(WeatherLook.of(WeatherSky.snow, Brightness.dark)!.isDark, isTrue);
    });

    test('the sun and fog stay still, the rest moves', () {
      expect(WeatherScene.sun.moves, isFalse);
      expect(WeatherScene.fog.moves, isFalse);
      expect(WeatherScene.rain.moves, isTrue);
      expect(WeatherScene.snow.moves, isTrue);
      expect(WeatherScene.stars.moves, isTrue);
      expect(WeatherScene.clouds.moves, isTrue);
    });
  });

  group('WeatherCubit.sky', () {
    WeatherCubit cubit(FakeWeatherRepository repository) => WeatherCubit(
      repository,
      FakeLocationSource()..permissionGranted = true,
    );

    test('is the sky of the weather shown', () async {
      final weather = cubit(FakeWeatherRepository());
      addTearDown(weather.close);
      expect(weather.sky, isNull);
      await weather.load();
      expect(weather.sky, WeatherSky.cloudy);
    });

    test('stays during a refresh and changes with the new weather', () async {
      final repository = FakeWeatherRepository();
      final weather = cubit(repository);
      addTearDown(weather.close);
      await weather.load();

      repository.pending = Completer();
      final refresh = weather.tap();
      await pumpEventQueue();
      expect(weather.state, isA<WeatherLoading>());
      expect(weather.sky, WeatherSky.cloudy);

      repository.pending!.complete(Ok(cloudyWithRain.withSky(WeatherSky.snow)));
      await refresh;
      expect(weather.sky, WeatherSky.snow);
    });

    test('is gone when the weather can no longer be shown', () async {
      final repository = FakeWeatherRepository();
      final weather = cubit(repository);
      addTearDown(weather.close);
      await weather.load();

      repository.reply = const Err(NetworkFailure());
      await weather.tap();
      expect(weather.state, isA<WeatherUnavailable>());
      expect(weather.sky, isNull);
    });
  });

  group('On the planner', () {
    Future<void> pumpPlanner(
      WidgetTester tester,
      Result<Weather> reply, {
      bool disableAnimations = false,
      bool tickers = true,
      FavouriteJourney? saved,
    }) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ProfileCubit(
                FakeProfileRepository('Shawn'),
                FakeAuthRepository(),
              ),
            ),
            BlocProvider(
              create: (_) => FavouriteJourneysCubit(
                FakeFavouriteJourneysRepository([?saved]),
              ),
            ),
            BlocProvider(create: (_) => TripFormCubit()),
            BlocProvider(
              create: (_) => WeatherCubit(
                FakeWeatherRepository(reply),
                FakeLocationSource()..permissionGranted = true,
              )..load(),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('de'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: child!,
            ),
            home: TickerMode(
              enabled: tickers,
              child: const TripFormView(showWeather: true),
            ),
          ),
        ),
      );
      // The weather arrives; the fade in takes less than this.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
    }

    Result<Weather> sky(WeatherSky sky) => Ok(cloudyWithRain.withSky(sky));

    /// How far the sky moves in one second.
    Future<double> movedInASecond(WidgetTester tester) async {
      final backdrop = tester.state<WeatherBackdropState>(
        find.byType(WeatherBackdrop),
      );
      final before = backdrop.seconds;
      await tester.pump(const Duration(seconds: 1));
      return backdrop.seconds - before;
    }

    testWidgets('rain keeps moving, 20 steps a second', (tester) async {
      await pumpPlanner(tester, sky(WeatherSky.rain));
      // 20 steps of 50 ms; one may still be due.
      expect(await movedInASecond(tester), closeTo(1, 0.051));
      expect(WeatherScene.rain.step, const Duration(milliseconds: 50));
    });

    testWidgets('clouds drift on, 10 steps a second', (tester) async {
      await pumpPlanner(tester, sky(WeatherSky.cloudy));
      expect(await movedInASecond(tester), closeTo(1, 0.101));
      expect(WeatherScene.clouds.step, const Duration(milliseconds: 100));
      expect(WeatherScene.stars.step, const Duration(milliseconds: 100));
    });

    testWidgets('rain stands still when animations are removed', (
      tester,
    ) async {
      await pumpPlanner(tester, sky(WeatherSky.rain), disableAnimations: true);
      expect(await movedInASecond(tester), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('rain stands still in a hidden tab', (tester) async {
      await pumpPlanner(tester, sky(WeatherSky.rain), tickers: false);
      expect(await movedInASecond(tester), 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('rain stands still while the app is in the background', (
      tester,
    ) async {
      await pumpPlanner(tester, sky(WeatherSky.rain));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(await movedInASecond(tester), 0);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(await movedInASecond(tester), greaterThan(0.9));
    });

    for (final still in [WeatherSky.clearDay, WeatherSky.fog]) {
      testWidgets('${still.name} stays still', (tester) async {
        await pumpPlanner(tester, sky(still));
        expect(await movedInASecond(tester), 0);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    }

    testWidgets('no weather, no background', (tester) async {
      await pumpPlanner(tester, const Err(NetworkFailure()));
      expect(find.byType(WeatherBackdrop), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('TalkBack reads greeting, chip and credit one by one', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPlanner(tester, sky(WeatherSky.clearDay));

      final greeting = tester.getSemantics(find.textContaining('Shawn')).label;
      final credit = tester
          .getSemantics(find.textContaining('Bright Sky'))
          .label;
      expect(greeting, contains('Shawn'));
      expect(greeting, isNot(contains('Bright Sky')));
      expect(credit, contains('Bright Sky'));
      expect(credit, isNot(contains('Shawn')));
      semantics.dispose();
    });

    testWidgets('a saved journey\'s bookmark is readable on a dark sky', (
      tester,
    ) async {
      await pumpPlanner(
        tester,
        sky(WeatherSky.clearNight),
        saved: FavouriteJourney(
          from: _from,
          to: _to,
          savedAt: DateTime.utc(2026, 11, 6),
        ),
      );
      tester.element(find.byType(TripFormView)).read<TripFormCubit>()
        ..setFrom(_from)
        ..setTo(_to);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final icon = tester.element(find.byIcon(Icons.bookmark));
      expect(IconTheme.of(icon).color, Colors.white);
    });

    for (final (weather, color) in [
      (WeatherSky.clearDay, Colors.black),
      (WeatherSky.thunderstorm, Colors.white),
    ]) {
      testWidgets('the empty bookmark is full strength on ${weather.name}', (
        tester,
      ) async {
        await pumpPlanner(tester, sky(weather));
        final icon = tester.element(find.byIcon(Icons.bookmark_border));
        expect(IconTheme.of(icon).color, color);
      });
    }

    testWidgets('the greeting takes the colour of the sky', (tester) async {
      await pumpPlanner(tester, sky(WeatherSky.clearNight));
      final look = WeatherLook.of(WeatherSky.clearNight, Brightness.light)!;
      final greeting = find.textContaining('Shawn');
      final style = tester
          .widget<AnimatedDefaultTextStyle>(
            find
                .ancestor(
                  of: greeting,
                  matching: find.byType(AnimatedDefaultTextStyle),
                )
                .first,
          )
          .style;
      expect(style.color, look.foreground);
    });
  });
}
