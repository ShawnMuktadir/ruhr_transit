import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/request_result.dart';
import 'package:ruhr_transit/features/nearby_stops/data/efa_coord_remote_source.dart';
import 'package:ruhr_transit/features/nearby_stops/data/nearby_stops_mapper.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stop.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';

class NearbyStopsRepositoryImpl implements NearbyStopsRepository {
  NearbyStopsRepositoryImpl(this._remote);

  final EfaCoordRemoteSource _remote;

  /// A refresh replaces the request before it.
  final _latest = LatestRequest();

  @override
  Future<Result<List<NearbyStop>>> stopsNear({
    required double latitude,
    required double longitude,
  }) => _latest.run(
    (cancelToken) => requestResult(() async {
      final json = await _remote.stopsNear(
        latitude: latitude,
        longitude: longitude,
        radiusMeters: NearbyStopsRepository.radiusMeters,
        cancelToken: cancelToken,
      );
      return mapCoordResponse(json);
    }),
  );
}
