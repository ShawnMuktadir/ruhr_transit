import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/request_result.dart';
import 'package:ruhr_transit/features/stop_search/data/efa_stop_remote_source.dart';
import 'package:ruhr_transit/features/stop_search/data/stop_mapper.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';

class StopRepositoryImpl implements StopRepository {
  StopRepositoryImpl(this._remote);

  final EfaStopRemoteSource _remote;

  /// Only the newest query matters; older requests should not use up
  /// bandwidth or the API's goodwill.
  final _latest = LatestRequest();

  @override
  Future<Result<List<Stop>>> searchStops(
    String query, {
    bool includeAddresses = false,
  }) => _latest.run(
    (cancelToken) => requestResult(() async {
      final json = await _remote.findStops(query, cancelToken: cancelToken);
      return mapStopFinderResponse(json, includeAddresses: includeAddresses);
    }),
  );

  @override
  Future<Result<Stop?>> locationAt({
    required double latitude,
    required double longitude,
  }) => requestResult(() async {
    final json = await _remote.findAt(latitude: latitude, longitude: longitude);
    return mapCoordLookupResponse(json);
  });
}
