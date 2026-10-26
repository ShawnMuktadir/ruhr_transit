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
}
