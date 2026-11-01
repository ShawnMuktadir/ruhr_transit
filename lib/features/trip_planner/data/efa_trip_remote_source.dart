import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';

/// Calls the EFA trip request. Returns the raw response object; mapping and
/// error translation happen in the repository.
class EfaTripRemoteSource {
  const EfaTripRemoteSource(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> trips(
    TripQuery query, {
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.get<String>(
      'XML_TRIP_REQUEST2',
      queryParameters: {
        // Stop IDs, not names: names like "Bochum Hbf" match several
        // locations and EFA answers "multiple matches".
        'type_origin': 'any',
        'name_origin': query.from.id,
        'type_destination': 'any',
        'name_destination': query.to.id,
        'useRealtime': '1',
        // EFA returns fewer when it finds fewer; live it sent 3 to 4.
        'calcNumberOfTrips': '5',
        'coordOutputFormat': 'WGS84[dd.ddddd]',
        ...switch (query.time) {
          // Without a time EFA plans from now.
          LeaveNow() => const <String, String>{},
          DepartAt(:final time) => _timeParameters(time, 'dep'),
          ArriveBy(:final time) => _timeParameters(time, 'arr'),
        },
      },
      cancelToken: cancelToken,
    );
    return decodeEfaJson(response.data);
  }

  /// EFA reads the time as German local time. The picked time is sent as
  /// shown on the phone, which matches while the phone is set to German
  /// time; converting other zones would need a time zone database.
  static Map<String, String> _timeParameters(DateTime time, String depArr) {
    String two(int n) => n.toString().padLeft(2, '0');
    return {
      'itdDate': '${time.year}${two(time.month)}${two(time.day)}',
      'itdTime': '${two(time.hour)}${two(time.minute)}',
      'itdTripDateTimeDepArr': depArr,
    };
  }
}
