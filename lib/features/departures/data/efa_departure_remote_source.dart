import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';

/// Calls the EFA departure monitor. Returns the raw response object; mapping
/// and error translation happen in the repository.
class EfaDepartureRemoteSource {
  const EfaDepartureRemoteSource(this._dio);

  /// About half an hour of departures at a busy stop like Bochum Hbf.
  static const limit = 30;

  final Dio _dio;

  Future<Map<String, Object?>> departuresAt(
    String stopId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<String>(
      'XML_DM_REQUEST',
      queryParameters: {
        'mode': 'direct',
        'type_dm': 'stop',
        'name_dm': stopId,
        'useRealtime': '1',
        'depType': 'stopEvents',
        'limit': '$limit',
      },
      cancelToken: cancelToken,
    );
    return decodeEfaJson(response.data);
  }
}
