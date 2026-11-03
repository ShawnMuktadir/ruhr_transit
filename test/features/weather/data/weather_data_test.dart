import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/weather/data/bright_sky_remote_source.dart';
import 'package:ruhr_transit/features/weather/data/weather_mapper.dart';
import 'package:ruhr_transit/features/weather/data/weather_repository_impl.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';

import '../../../helpers/fake_http_adapter.dart';

String _fixture(String name) =>
    File('test/fixtures/brightsky/$name.json').readAsStringSync();

Map<String, Object?> _json(String name) =>
    jsonDecode(_fixture(name)) as Map<String, Object?>;

/// A forecast hour shaped like Bright Sky's, with only the fields read.
Map<String, Object?> _hour(String timestamp, String condition, [int p = 0]) => {
  'timestamp': timestamp,
  'condition': condition,
  'precipitation_probability': p,
};

void main() {
  group('mapWeather with recorded responses', () {
    test('maps the current weather in Bochum, dry for the next hours', () {
      final weather = mapWeather(
        _json('current_bochum'),
        _json('forecast_bochum'),
      );

      expect(weather.sky, WeatherSky.cloudy);
      expect(weather.temperature, isNotNull);
      expect(weather.observedAt.isUtc, isTrue);
      // All 13 forecast hours are "dry" with at most 16 % rain.
      expect(weather.precipitation, isNull);
    });
  });

  group('mapWeather', () {
    final current = {
      'weather': {
        'timestamp': '2026-11-02T20:00:00+01:00',
        'condition': 'dry',
        'icon': 'partly-cloudy-night',
        'temperature': -0.4,
      },
    };

    test('finds the first rainy hour after now', () {
      final weather = mapWeather(current, {
        'weather': [
          _hour('2026-11-02T19:00:00+00:00', 'rain'), // now: not "after"
          _hour('2026-11-02T20:00:00+00:00', 'dry', 30),
          _hour('2026-11-02T21:00:00+00:00', 'thunderstorm'),
          _hour('2026-11-02T22:00:00+00:00', 'snow'),
        ],
      });

      expect(weather.sky, WeatherSky.partlyCloudyNight);
      expect(weather.temperature, -0.4);
      expect(weather.precipitation?.kind, PrecipitationKind.rain);
      expect(weather.precipitation?.startsAt, DateTime.utc(2026, 11, 2, 21));
      expect(weather.precipitation?.isNow, isFalse);
    });

    test('a likely shower counts although the hour is still "dry"', () {
      final weather = mapWeather(current, {
        'weather': [
          _hour('2026-11-02T20:00:00+00:00', 'dry', 59),
          _hour('2026-11-02T21:00:00+00:00', 'dry', rainProbabilityThreshold),
        ],
      });

      expect(weather.precipitation?.startsAt, DateTime.utc(2026, 11, 2, 21));
    });

    test('snow is snow', () {
      final weather = mapWeather(current, {
        'weather': [_hour('2026-11-02T20:00:00+00:00', 'snow')],
      });

      expect(weather.precipitation?.kind, PrecipitationKind.snow);
    });

    test('rain now needs no forecast', () {
      final weather = mapWeather({
        'weather': {
          'timestamp': '2026-11-02T20:00:00+01:00',
          'condition': 'sleet',
          'icon': 'sleet',
        },
      });

      expect(weather.sky, WeatherSky.sleet);
      expect(weather.temperature, isNull);
      expect(weather.precipitation?.isNow, isTrue);
      expect(weather.precipitation?.kind, PrecipitationKind.rain);
    });

    test('an unknown or missing icon is unknown', () {
      final weather = mapWeather({
        'weather': {'timestamp': '2026-11-02T20:00:00+01:00', 'icon': null},
      });

      expect(weather.sky, WeatherSky.unknown);
    });

    test('broken shapes are FormatExceptions', () {
      expect(() => mapWeather({}), throwsFormatException);
      expect(
        () => mapWeather({
          'weather': {'icon': 'cloudy'},
        }),
        throwsFormatException,
      );
    });
  });

  group('WeatherRepositoryImpl', () {
    late FakeHttpAdapter adapter;

    WeatherRepositoryImpl repositoryAnswering(
      Future<ResponseBody> Function(RequestOptions options) handler,
    ) {
      adapter = FakeHttpAdapter(handler);
      final dio = createBrightSkyDio(baseUrl: 'https://weather.test')
        ..httpClientAdapter = adapter;
      return WeatherRepositoryImpl(
        BrightSkyRemoteSource(dio),
        now: () => DateTime.utc(2026, 11, 2, 19, 36),
      );
    }

    Future<Result<Weather>> atBochumHbf(WeatherRepositoryImpl repository) =>
        repository.weatherAt(latitude: 51.479466, longitude: 7.223335);

    test('asks for now and the next six hours, at about 1 km', () async {
      final repository = repositoryAnswering(
        (options) async => textResponse(
          _fixture(
            options.path == 'current_weather'
                ? 'current_bochum'
                : 'forecast_bochum',
          ),
        ),
      );

      final result = await atBochumHbf(repository);

      expect(result, isA<Ok<Weather>>());
      final [current, hourly] = adapter.requests
        ..sort((a, b) => a.path.compareTo(b.path));
      expect(current.uri.toString(), contains('/current_weather?'));
      expect(current.uri.queryParameters, {'lat': '51.48', 'lon': '7.22'});
      expect(hourly.uri.path, '/weather');
      expect(hourly.uri.queryParameters, {
        'lat': '51.48',
        'lon': '7.22',
        'date': '2026-11-02T19:00:00.000Z',
        'last_date': '2026-11-03T01:00:00.000Z',
      });
    });

    test('without the forecast, the current weather still shows', () async {
      final repository = repositoryAnswering(
        (options) async => options.path == 'current_weather'
            ? textResponse(_fixture('current_bochum'))
            : textResponse('oops', statusCode: 500),
      );

      final result = await atBochumHbf(repository);

      expect((result as Ok<Weather>).value.sky, WeatherSky.cloudy);
    });

    test('outside Germany: 404', () async {
      final repository = repositoryAnswering(
        (_) async => textResponse(
          '{"detail":"No sources match your criteria"}',
          statusCode: 404,
        ),
      );

      expect(
        await atBochumHbf(repository),
        isA<Err<Weather>>().having(
          (e) => e.failure,
          'failure',
          isA<ServerFailure>().having((f) => f.code, 'code', 404),
        ),
      );
    });

    test('no connection is a NetworkFailure', () async {
      final repository = repositoryAnswering(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );

      expect(
        await atBochumHbf(repository),
        isA<Err<Weather>>().having(
          (e) => e.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
      );
    });

    test('a body that is not JSON is a ParseFailure', () async {
      final repository = repositoryAnswering(
        (_) async => textResponse('<html>'),
      );

      expect(
        await atBochumHbf(repository),
        isA<Err<Weather>>().having(
          (e) => e.failure,
          'failure',
          isA<ParseFailure>(),
        ),
      );
    });
  });
}
