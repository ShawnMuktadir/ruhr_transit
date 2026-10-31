import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_error_mapper.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/departures/data/departure_mapper.dart';
import 'package:ruhr_transit/features/departures/data/efa_departure_remote_source.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';

class DepartureRepositoryImpl implements DepartureRepository {
  DepartureRepositoryImpl(this._remote);

  final EfaDepartureRemoteSource _remote;

  /// The request that is still running, if any. Holding this makes the
  /// repository stateful, so it is registered as a factory: one per page.
  CancelToken? _inFlight;

  @override
  Future<Result<List<Departure>>> departuresAt(String stopId) async {
    // A second refresh replaces the first; only the newest answer matters.
    _inFlight?.cancel();
    final cancelToken = _inFlight = CancelToken();
    try {
      final json = await _remote.departuresAt(stopId, cancelToken: cancelToken);
      return Ok(mapDepartureMonitorResponse(json));
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
