import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/nearby_stops/domain/location_source.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';
import 'package:ruhr_transit/features/weather/domain/weather_repository.dart';

/// What the weather chip shows. Sealed, so the chip handles every case.
sealed class WeatherState {
  const WeatherState();
}

final class WeatherLoading extends WeatherState {
  const WeatherLoading();
}

final class WeatherShown extends WeatherState {
  const WeatherShown(this.weather, {required this.fetchedAt});

  final Weather weather;
  final DateTime fetchedAt;
}

/// The app may not read the location yet. [permanently]: Android no longer
/// asks, only the app settings can allow it.
final class WeatherNeedsPermission extends WeatherState {
  const WeatherNeedsPermission({this.permanently = false});

  final bool permanently;
}

/// Location is turned off on the phone.
final class WeatherLocationOff extends WeatherState {
  const WeatherLocationOff();
}

enum WeatherProblem {
  /// No internet connection, or the server did not answer in time.
  offline,

  /// No data for this place: Bright Sky only covers Germany.
  notHere,

  /// No position arrived in time.
  noPosition,

  /// Anything else went wrong.
  failed,
}

final class WeatherUnavailable extends WeatherState {
  const WeatherUnavailable(this.problem);

  final WeatherProblem problem;
}

/// The weather where the user is, for the planner. Never asks for the
/// location permission by itself: only [tap] does, when the user taps the
/// chip that asks for it.
class WeatherCubit extends Cubit<WeatherState> {
  WeatherCubit(this._weather, this._location, {DateTime Function()? now})
    : _now = now ?? DateTime.now,
      super(const WeatherLoading());

  final WeatherRepository _weather;
  final LocationSource _location;
  final DateTime Function() _now;

  /// Older weather is fetched again when the app comes back.
  static const maxAge = Duration(minutes: 30);

  /// Shows the weather if the location may be read, else what is needed.
  Future<void> load() async {
    if (!await _location.hasPermission()) {
      _emit(const WeatherNeedsPermission());
      return;
    }
    await _locateAndFetch();
  }

  /// The user tapped the chip.
  Future<void> tap() async {
    switch (state) {
      case WeatherLoading():
        return;
      case WeatherNeedsPermission(permanently: true):
        // Back from the settings, [resumed] loads again.
        await _location.openAppSettings();
      case WeatherLocationOff():
        await _location.openLocationSettings();
      case WeatherNeedsPermission() || WeatherShown() || WeatherUnavailable():
        // Asks for the permission if needed: the user asked for it.
        await _locateAndFetch();
    }
  }

  /// The app is in the foreground again, maybe back from the settings.
  Future<void> resumed() async {
    switch (state) {
      case WeatherLoading():
        return;
      case WeatherShown(:final fetchedAt)
          when _now().difference(fetchedAt) < maxAge:
        return;
      case WeatherNeedsPermission(permanently: false):
        // Only check: asking again on every return would nag.
        if (await _location.hasPermission()) await _locateAndFetch();
      case WeatherNeedsPermission() ||
          WeatherLocationOff() ||
          WeatherShown() ||
          WeatherUnavailable():
        await load();
    }
  }

  Future<void> _locateAndFetch() async {
    _emit(const WeatherLoading());
    switch (await _location.currentLocation()) {
      case LocationOff():
        _emit(const WeatherLocationOff());
      case LocationPermissionDenied(:final permanently):
        _emit(WeatherNeedsPermission(permanently: permanently));
      case LocationTimeout():
        _emit(const WeatherUnavailable(WeatherProblem.noPosition));
      case Located(:final latitude, :final longitude):
        final result = await _weather.weatherAt(
          latitude: latitude,
          longitude: longitude,
        );
        _emit(switch (result) {
          Ok(:final value) => WeatherShown(value, fetchedAt: _now()),
          Err(failure: NetworkFailure() || TimeoutFailure()) =>
            const WeatherUnavailable(WeatherProblem.offline),
          Err(failure: ServerFailure(code: 404)) => const WeatherUnavailable(
            WeatherProblem.notHere,
          ),
          Err() => const WeatherUnavailable(WeatherProblem.failed),
        });
    }
  }

  void _emit(WeatherState state) {
    if (!isClosed) emit(state);
  }
}
