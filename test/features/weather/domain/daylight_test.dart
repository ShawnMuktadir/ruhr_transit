import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/weather/domain/daylight.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';

void main() {
  // Bochum: sunrise about 5:13 and sunset 21:52 (CEST) on 21 June, 8:32
  // and 16:24 (CET) on 21 December.
  test('summer: a long day', () {
    expect(isDaylight(DateTime.utc(2026, 6, 21, 3)), isFalse);
    expect(isDaylight(DateTime.utc(2026, 6, 21, 3, 30)), isTrue);
    expect(isDaylight(DateTime.utc(2026, 6, 21, 19, 40)), isTrue);
    expect(isDaylight(DateTime.utc(2026, 6, 21, 20, 10)), isFalse);
  });

  test('winter: a short day', () {
    expect(isDaylight(DateTime.utc(2026, 12, 21, 7, 15)), isFalse);
    expect(isDaylight(DateTime.utc(2026, 12, 21, 7, 50)), isTrue);
    expect(isDaylight(DateTime.utc(2026, 12, 21, 15, 10)), isTrue);
    expect(isDaylight(DateTime.utc(2026, 12, 21, 15, 45)), isFalse);
  });

  test('without weather, partly cloudy by day or night', () {
    expect(
      skyWithoutWeather(DateTime.utc(2026, 11, 20, 12)),
      WeatherSky.partlyCloudyDay,
    );
    expect(
      skyWithoutWeather(DateTime.utc(2026, 11, 20, 22)),
      WeatherSky.partlyCloudyNight,
    );
  });
}
