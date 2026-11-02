import 'package:dio/dio.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/efa_error_mapper.dart';
import 'package:ruhr_transit/core/network/efa_json.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_run_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/run_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';

class VehicleRunRepositoryImpl implements VehicleRunRepository {
  VehicleRunRepositoryImpl(this._remote);

  final EfaRunRemoteSource _remote;

  /// The request still running, if any; one repository per ride, so it is
  /// registered as a factory.
  CancelToken? _inFlight;

  @override
  Future<Result<VehicleRun>> run(RunKey key) async {
    _inFlight?.cancel();
    final cancelToken = _inFlight = CancelToken();
    try {
      final json = await _remote.run(key, cancelToken: cancelToken);
      return Ok(mapRunResponse(json));
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
