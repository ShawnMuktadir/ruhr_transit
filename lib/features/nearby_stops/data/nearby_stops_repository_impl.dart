import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_error_mapper.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/nearby_stops/data/efa_coord_remote_source.dart';
import 'package:ruhr_transit/features/nearby_stops/data/nearby_stops_mapper.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';

class NearbyStopsRepositoryImpl implements NearbyStopsRepository {
  NearbyStopsRepositoryImpl(this._remote);

  final EfaCoordRemoteSource _remote;

  /// The request that is still running, if any. Holding this makes the
  /// repository stateful, so it is registered as a factory: one per page.
  CancelToken? _inFlight;

  @override
  Future<Result<List<NearbyStop>>> stopsNear({
    required double latitude,
    required double longitude,
  }) async {
    // A refresh replaces the request before it; only the newest answer
    // matters.
    _inFlight?.cancel();
    final cancelToken = _inFlight = CancelToken();
    try {
      final json = await _remote.stopsNear(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: NearbyStopsRepository.radiusMeters,
        cancelToken: cancelToken,
      );
      return Ok(mapCoordResponse(json));
    } on DioException catch (e) {
      return Err(failureFromDioException(e));
    } on EfaServerException catch (e) {
      return Err(ServerFailure(code: e.code, message: e.message));
    } on FormatException catch (e) {
      return Err(ParseFailure(e.message));
    } finally {
      if (identical(_inFlight, cancelToken)) _inFlight = null;
    }
  }
}
