import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';

/// Calls the EFA coordinate request for stops around a point. Returns the
/// raw response object; mapping and error translation happen in the
/// repository.
class EfaCoordRemoteSource {
  const EfaCoordRemoteSource(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> stopsNear({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    CancelToken? cancelToken,
  }) async {
    const wgs84 = 'WGS84[dd.ddddd]';
    final response = await _dio.get<String>(
      'XML_COORD_REQUEST',
      queryParameters: {
        // EFA expects longitude first: lon:lat:format.
        'coord': '$longitude:$latitude:$wgs84',
        'coordOutputFormat': wgs84,
        // Only stops; without the filter EFA also returns POIs and streets.
        'inclFilter': '1',
        'type_1': 'STOP',
        'radius_1': '$radiusMeters',
        'max': '20',
      },
      cancelToken: cancelToken,
    );
    return decodeEfaJson(response.data);
  }
}
