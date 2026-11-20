import 'dart:math' as math;

import 'package:ruhr_transit/features/weather/domain/weather.dart';

/// Whether the sun is up at [time] at the given place, by the sun's
/// position (NOAA's approximation, within a few minutes). Defaults to the
/// middle of the Ruhr area: the planner's sky needs no exact place, and it
/// must work without a location.
bool isDaylight(
  DateTime time, {
  double latitude = 51.48,
  double longitude = 7.22,
}) {
  final utc = time.toUtc();
  final dayOfYear = utc.difference(DateTime.utc(utc.year)).inDays + 1;
  final hours = utc.hour + utc.minute / 60 + utc.second / 3600;
  final year = (2 * math.pi / 365) * (dayOfYear - 1 + (hours - 12) / 24);

  // Minutes the sun is ahead of or behind the clock over the year.
  final equationOfTime =
      229.18 *
      (0.000075 +
          0.001868 * math.cos(year) -
          0.032077 * math.sin(year) -
          0.014615 * math.cos(2 * year) -
          0.040849 * math.sin(2 * year));
  final declination =
      0.006918 -
      0.399912 * math.cos(year) +
      0.070257 * math.sin(year) -
      0.006758 * math.cos(2 * year) +
      0.000907 * math.sin(2 * year) -
      0.002697 * math.cos(3 * year) +
      0.00148 * math.sin(3 * year);

  final solarMinutes = hours * 60 + equationOfTime + 4 * longitude;
  final hourAngle = (solarMinutes / 4 - 180) * math.pi / 180;
  final lat = latitude * math.pi / 180;
  final cosZenith =
      math.sin(lat) * math.sin(declination) +
      math.cos(lat) * math.cos(declination) * math.cos(hourAngle);
  // Up from when its upper edge shows, with the air's bending: 90.833°.
  return cosZenith > math.cos(90.833 * math.pi / 180);
}

/// The planner's sky while there is no weather to show: loading, offline,
/// or no location. Partly cloudy, the least telling weather, by day or by
/// night, so the header still moves; the chip says what is missing.
WeatherSky skyWithoutWeather(DateTime time) => isDaylight(time)
    ? WeatherSky.partlyCloudyDay
    : WeatherSky.partlyCloudyNight;
