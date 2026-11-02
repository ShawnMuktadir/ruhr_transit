import 'dart:convert';

import 'package:dio/dio.dart';

/// Calls Bright Sky (api.brightsky.dev), which serves Deutscher
/// Wetterdienst open data. Returns the decoded JSON; mapping and error
/// translation happen in the repository.
class BrightSkyRemoteSource {
  const BrightSkyRemoteSource(this._dio);

  final Dio _dio;

  /// The latest observation near the point (`current_weather`).
  Future<Map<String, Object?>> current({
    required double latitude,
    required double longitude,
  }) => _get('current_weather', {'lat': latitude, 'lon': longitude});

  /// Hourly forecast from [from] to [to] (`weather`).
  Future<Map<String, Object?>> hourly({
    required double latitude,
    required double longitude,
    required DateTime from,
    required DateTime to,
  }) => _get('weather', {
    'lat': latitude,
    'lon': longitude,
    'date': from.toUtc().toIso8601String(),
    'last_date': to.toUtc().toIso8601String(),
  });

  Future<Map<String, Object?>> _get(
    String path,
    Map<String, Object?> query,
  ) async {
    final response = await _dio.get<String>(path, queryParameters: query);
    return switch (jsonDecode(response.data ?? '')) {
      final Map<String, Object?> json => json,
      _ => throw const FormatException('Not a JSON object'),
    };
  }
}
