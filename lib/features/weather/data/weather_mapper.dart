import 'package:ruhr_transit/features/weather/domain/weather.dart';

/// A forecast hour counts as rainy from this `precipitation_probability`
/// (%), even when its `condition` is still "dry".
const rainProbabilityThreshold = 60;

/// Maps Bright Sky's `current_weather` response and, if it arrived, the
/// hourly `weather` forecast. Throws [FormatException] when the shape is
/// wrong.
Weather mapWeather(
  Map<String, Object?> current, [
  Map<String, Object?>? forecast,
]) {
  final now = switch (current['weather']) {
    final Map<String, Object?> weather => weather,
    _ => throw const FormatException('current_weather without weather'),
  };
  final observedAt = _time(now['timestamp']);
  if (observedAt == null) {
    throw const FormatException('current_weather without timestamp');
  }

  PrecipitationOutlook? precipitation;
  if (_kind(now['condition']) case final kind?) {
    precipitation = PrecipitationOutlook(
      kind: kind,
      startsAt: observedAt,
      isNow: true,
    );
  } else if (forecast?['weather'] case final List<Object?> hours) {
    for (final hour in hours) {
      if (hour is! Map<String, Object?>) continue;
      final at = _time(hour['timestamp']);
      if (at == null || !at.isAfter(observedAt)) continue;
      final kind =
          _kind(hour['condition']) ??
          switch (hour['precipitation_probability']) {
            final num p when p >= rainProbabilityThreshold =>
              PrecipitationKind.rain,
            _ => null,
          };
      if (kind != null) {
        precipitation = PrecipitationOutlook(
          kind: kind,
          startsAt: at,
          isNow: false,
        );
        break;
      }
    }
  }

  return Weather(
    sky: switch (now['icon']) {
      'clear-day' => WeatherSky.clearDay,
      'clear-night' => WeatherSky.clearNight,
      'partly-cloudy-day' => WeatherSky.partlyCloudyDay,
      'partly-cloudy-night' => WeatherSky.partlyCloudyNight,
      'cloudy' => WeatherSky.cloudy,
      'fog' => WeatherSky.fog,
      'wind' => WeatherSky.wind,
      'rain' => WeatherSky.rain,
      'sleet' => WeatherSky.sleet,
      'snow' => WeatherSky.snow,
      'hail' => WeatherSky.hail,
      'thunderstorm' => WeatherSky.thunderstorm,
      _ => WeatherSky.unknown,
    },
    temperature: switch (now['temperature']) {
      final num celsius => celsius.toDouble(),
      _ => null,
    },
    observedAt: observedAt,
    precipitation: precipitation,
  );
}

/// Bright Sky's `condition`: dry, fog, rain, sleet, snow, hail,
/// thunderstorm.
PrecipitationKind? _kind(Object? condition) => switch (condition) {
  'rain' || 'sleet' || 'hail' || 'thunderstorm' => PrecipitationKind.rain,
  'snow' => PrecipitationKind.snow,
  _ => null,
};

DateTime? _time(Object? json) => switch (json) {
  final String text => DateTime.tryParse(text)?.toUtc(),
  _ => null,
};
