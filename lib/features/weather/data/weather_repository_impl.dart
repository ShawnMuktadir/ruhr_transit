import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_error_mapper.dart';
import 'package:ruhr_transit/features/weather/data/bright_sky_remote_source.dart';
import 'package:ruhr_transit/features/weather/data/weather_mapper.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';
import 'package:ruhr_transit/features/weather/domain/weather_repository.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  WeatherRepositoryImpl(this._remote, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final BrightSkyRemoteSource _remote;
  final DateTime Function() _now;

  /// How far ahead the rain hint looks.
  static const outlook = Duration(hours: 6);

  /// Coordinates are rounded to about 1 km before they leave the phone:
  /// plenty for the weather, less precise about where the user is.
  static double round(double degrees) => (degrees * 100).round() / 100;

  @override
  Future<Result<Weather>> weatherAt({
    required double latitude,
    required double longitude,
  }) async {
    final lat = round(latitude);
    final lon = round(longitude);
    final now = _now().toUtc();
    final hour = DateTime.utc(now.year, now.month, now.day, now.hour);
    // Both at once; the forecast never throws.
    final forecast = _forecast(lat, lon, hour);
    try {
      final current = await _remote.current(latitude: lat, longitude: lon);
      return Ok(mapWeather(current, await forecast));
    } on DioException catch (e) {
      return Err(failureFromDioException(e));
    } on FormatException catch (e) {
      return Err(ParseFailure(e.message));
    } finally {
      // Not left unawaited when the current weather failed.
      await forecast;
    }
  }

  /// The forecast only adds the rain hint: without it the current weather
  /// still shows.
  Future<Map<String, Object?>?> _forecast(
    double lat,
    double lon,
    DateTime from,
  ) async {
    try {
      return await _remote.hourly(
        latitude: lat,
        longitude: lon,
        from: from,
        to: from.add(outlook),
      );
    } on Object catch (e) {
      debugPrint('No weather forecast: $e');
      return null;
    }
  }
}
