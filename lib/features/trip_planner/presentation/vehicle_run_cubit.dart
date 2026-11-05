import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';

sealed class VehicleRunState {
  const VehicleRunState();
}

final class VehicleRunLoading extends VehicleRunState {
  const VehicleRunLoading();
}

/// [now] is when the state was made; the position is calculated for it.
final class VehicleRunLoaded extends VehicleRunState {
  const VehicleRunLoaded(this.run, {required this.now, this.isPaused = false});

  final VehicleRun run;
  final DateTime now;

  /// No connection: [now] stays the time of the last answer, as moving the
  /// vehicle on from old data would be a guess that looks like a fact.
  final bool isPaused;

  RunPosition get position => run.positionAt(now);
}

/// The run could not be loaded; trip details then show the ride without
/// its run, as before.
final class VehicleRunFailed extends VehicleRunState {
  const VehicleRunFailed(this.failure);

  final Failure failure;
}

/// One ride's whole run, refreshed every [refreshEvery] while trip details
/// are open, so live times and the position stay current.
class VehicleRunCubit extends Cubit<VehicleRunState> {
  VehicleRunCubit(
    this._repository,
    this._key, {
    DateTime Function() now = DateTime.now,
    this.refreshEvery = const Duration(seconds: 30),
  }) : _now = now,
       super(const VehicleRunLoading());

  final VehicleRunRepository _repository;
  final RunKey _key;
  final DateTime Function() _now;
  final Duration refreshEvery;
  Timer? _timer;

  /// Loads now and then every [refreshEvery].
  Future<void> start() async {
    _timer ??= Timer.periodic(refreshEvery, (_) => unawaited(load()));
    await load();
  }

  Future<void> load() async {
    final result = await _repository.run(_key);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(VehicleRunLoaded(value, now: _now()));
      // A newer request replaced this one.
      case Err(failure: CancelledFailure()):
        return;
      case Err(:final failure):
        // A failed refresh keeps the run shown so far; only a first failure
        // shows as such. Without a connection the position pauses, after a
        // server hiccup the times still hold and it moves on.
        emit(switch ((state, failure)) {
          (
            VehicleRunLoaded(:final run, :final now),
            NetworkFailure() || TimeoutFailure(),
          ) =>
            VehicleRunLoaded(run, now: now, isPaused: true),
          (VehicleRunLoaded(:final run), _) => VehicleRunLoaded(
            run,
            now: _now(),
          ),
          _ => VehicleRunFailed(failure),
        });
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
