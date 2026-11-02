import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_error_mapper.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/stop_search/data/efa_stop_remote_source.dart';
import 'package:ruhr_transit/features/stop_search/data/stop_mapper.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';

class StopRepositoryImpl implements StopRepository {
  StopRepositoryImpl(this._remote);

  final EfaStopRemoteSource _remote;

  /// The search that is still running, if any. Holding this makes the
  /// repository stateful, so it is registered as a factory: one per page.
  CancelToken? _inFlight;

  @override
  Future<Result<List<Stop>>> searchStops(
    String query, {
    bool includeAddresses = false,
  }) async {
    // Only the newest query matters; don't let older requests use up
    // bandwidth or the API's goodwill.
    _inFlight?.cancel();
    final cancelToken = _inFlight = CancelToken();
    try {
      final json = await _remote.findStops(query, cancelToken: cancelToken);
      return Ok(
        mapStopFinderResponse(json, includeAddresses: includeAddresses),
      );
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
