import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/nearby_stops_repository.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_state.dart';

/// Stops around the user. Reads the location once per [load]; nothing is
/// tracked while the page is open.
class NearbyStopsCubit extends Cubit<NearbyStopsState> {
  NearbyStopsCubit(this._location, this._repository)
    : super(const NearbyLocating());

  final LocationSource _location;
  final NearbyStopsRepository _repository;

  /// Whether a [load] is running. Android allows one permission request at
  /// a time, so a second tap must not start another.
  bool _busy = false;

  /// On opening: searches right away if the permission was granted before,
  /// otherwise explains first and asks only when the user taps the button.
  Future<void> start() async {
    if (await _location.hasPermission()) {
      await load();
    } else if (!isClosed) {
      emit(const NearbyIntro());
    }
  }

  /// Reads the location, then loads the stops around it. Used after the
  /// intro, on refresh and to retry.
  Future<void> load() async {
    if (_busy) return;
    _busy = true;
    try {
      emit(const NearbyLocating());
      final location = await _location.currentLocation();
      if (isClosed) return;
      if (location is! Located) {
        emit(NearbyLocationProblem(location));
        return;
      }

      emit(const NearbyLoading());
      final result = await _repository.stopsNear(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (isClosed) return;
      switch (result) {
        case Ok(value: final stops):
          emit(NearbyLoaded(stops, isApproximate: location.isApproximate));
        // Only one request runs at a time here, but the repository's
        // contract allows it; nothing to show for it.
        case Err(failure: CancelledFailure()):
          return;
        case Err(:final failure):
          emit(NearbyFailed(failure));
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> openAppSettings() => _location.openAppSettings();

  Future<void> openLocationSettings() => _location.openLocationSettings();
}
