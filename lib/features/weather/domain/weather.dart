/// The sky as Bright Sky's `icon` describes it.
enum WeatherSky {
  clearDay,
  clearNight,
  partlyCloudyDay,
  partlyCloudyNight,
  cloudy,
  fog,
  wind,
  rain,
  sleet,
  snow,
  hail,
  thunderstorm,

  /// Bright Sky sends no icon, or one this app does not know.
  unknown,
}

enum PrecipitationKind { rain, snow }

/// Rain or snow now or in the next hours: worth taking an umbrella.
class PrecipitationOutlook {
  const PrecipitationOutlook({
    required this.kind,
    required this.startsAt,
    required this.isNow,
  });

  final PrecipitationKind kind;

  /// The hour it starts, in UTC.
  final DateTime startsAt;

  /// It is raining or snowing already.
  final bool isNow;
}

/// The weather where the user is, from Deutscher Wetterdienst data.
class Weather {
  const Weather({
    required this.sky,
    required this.observedAt,
    this.temperature,
    this.precipitation,
  });

  final WeatherSky sky;

  /// °C; null when the station has no reading.
  final double? temperature;

  /// When the reading was taken, in UTC.
  final DateTime observedAt;

  /// Rain or snow now or within the next hours; null when it stays dry.
  final PrecipitationOutlook? precipitation;
}
