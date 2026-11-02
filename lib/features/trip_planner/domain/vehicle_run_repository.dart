import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';

abstract interface class VehicleRunRepository {
  /// The whole run identified by [key], with live times where EFA has them.
  ///
  /// Starting a new request cancels the previous one on the same instance;
  /// the cancelled call completes with a `CancelledFailure`.
  Future<Result<VehicleRun>> run(RunKey key);
}
