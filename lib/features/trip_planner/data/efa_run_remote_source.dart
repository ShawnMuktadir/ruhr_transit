import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

/// Calls EFA's stop sequence request for one vehicle's whole run. Returns
/// the raw response object; mapping happens in the repository.
class EfaRunRemoteSource {
  const EfaRunRemoteSource(this._dio);

  final Dio _dio;

  Future<Map<String, Object?>> run(RunKey key, {CancelToken? cancelToken}) {
    // EFA reads date and time as German local time, like the trip request
    // (see EfaTripRemoteSource): right while the phone is on German time.
    final local = key.plannedDeparture.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return _dio
        .get<String>(
          'XML_STOPSEQCOORD_REQUEST',
          queryParameters: {
            // May contain a space (`ddb:90RE1: :H:j26`); Dio encodes it.
            'line': key.lineId,
            'stop': key.stopId,
            'tripCode': key.tripCode,
            'date': '${local.year}${two(local.month)}${two(local.day)}',
            'time': '${two(local.hour)}${two(local.minute)}',
            // Every stop of the run, not only those after `stop`.
            'tStOTType': 'all',
            'useRealtime': '1',
            // Points as latitude/longitude for the map (EFA's own
            // projection otherwise).
            'coordOutputFormat': 'WGS84[dd.ddddd]',
          },
          cancelToken: cancelToken,
        )
        .then((response) => decodeEfaJson(response.data));
  }
}
