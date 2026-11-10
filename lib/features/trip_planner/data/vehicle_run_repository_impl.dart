import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/network/request_result.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_run_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/run_mapper.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';

class VehicleRunRepositoryImpl implements VehicleRunRepository {
  VehicleRunRepositoryImpl(this._remote);

  final EfaRunRemoteSource _remote;

  /// One repository per ride; a reload replaces the request before it.
  final _latest = LatestRequest();

  @override
  Future<Result<VehicleRun>> run(RunKey key) => _latest.run(
    (cancelToken) => requestResult(() async {
      final json = await _remote.run(key, cancelToken: cancelToken);
      return mapRunResponse(json);
    }),
  );
}
