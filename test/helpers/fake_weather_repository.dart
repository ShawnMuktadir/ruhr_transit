import 'dart:async';

import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';
import 'package:ruhr_transit/features/weather/domain/weather_repository.dart';

/// Records the points asked for and answers with [reply], or waits for
/// [pending] if set.
class FakeWeatherRepository implements WeatherRepository {
  FakeWeatherRepository([Result<Weather>? reply])
    : reply = reply ?? Ok(cloudyWithRain);

  Result<Weather> reply;
  Completer<Result<Weather>>? pending;
  final List<(double, double)> points = [];

  @override
  Future<Result<Weather>> weatherAt({
    required double latitude,
    required double longitude,
  }) {
    points.add((latitude, longitude));
    return pending?.future ?? Future.value(reply);
  }
}

extension WeatherWithSky on Weather {
  Weather withSky(WeatherSky sky) => Weather(
    sky: sky,
    temperature: temperature,
    observedAt: observedAt,
    precipitation: precipitation,
  );
}

/// 9 °C and cloudy at 19:00 UTC, rain from 21:00 UTC.
final cloudyWithRain = Weather(
  sky: WeatherSky.cloudy,
  temperature: 9.1,
  observedAt: DateTime.utc(2026, 11, 2, 19),
  precipitation: PrecipitationOutlook(
    kind: PrecipitationKind.rain,
    startsAt: DateTime.utc(2026, 11, 2, 21),
    isNow: false,
  ),
);
