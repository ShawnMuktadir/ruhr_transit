import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';

/// Calls the EFA stop finder. Returns the raw response object; mapping and
/// error translation happen in the repository.
class EfaStopRemoteSource {
  const EfaStopRemoteSource(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> findStops(
    String query, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<String>(
      'XML_STOPFINDER_REQUEST',
      queryParameters: {
        'type_sf': 'any',
        'name_sf': query,
        'coordOutputFormat': 'WGS84[dd.ddddd]',
      },
      cancelToken: cancelToken,
    );
    return decodeEfaJson(response.data);
  }

  /// The address or stop at a point (`type_sf=coord`), for "current
  /// location". Rounded to 4 decimals, about 10 m: enough for a start.
  Future<Map<String, Object?>> findAt({
    required double latitude,
    required double longitude,
  }) async {
    const wgs84 = 'WGS84[dd.ddddd]';
    final response = await _dio.get<String>(
      'XML_STOPFINDER_REQUEST',
      queryParameters: {
        'type_sf': 'coord',
        // EFA expects longitude first: lon:lat:format.
        'name_sf':
            '${longitude.toStringAsFixed(4)}:'
            '${latitude.toStringAsFixed(4)}:$wgs84',
        'coordOutputFormat': wgs84,
      },
    );
    return decodeEfaJson(response.data);
  }
}
