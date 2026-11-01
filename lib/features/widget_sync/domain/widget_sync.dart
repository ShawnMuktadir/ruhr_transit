import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Keeps the home-screen widget in step with the app.
///
/// The widget shows one stop, chosen in the app. It never fetches anything
/// itself: the VRR terms allow user-triggered queries only, so it shows
/// what the app fetched last for that stop.
///
/// The widget is a convenience: implementations log their errors instead
/// of failing the app.
abstract interface class WidgetSync {
  /// Makes [stop] the stop of the widget, with [board] if one is at hand.
  Future<void> showStop(Stop stop, {DepartureBoard? board});

  /// Shows [board] on the widget if [stopId] is the widget's stop.
  Future<void> boardFetched(String stopId, DepartureBoard board);

  /// The stop whose widget started the app, if it was started that way.
  Future<Stop?> launchedStop();

  /// Stops whose widget was tapped while the app was running.
  Stream<Stop> get openedStops;

  /// Whether the app can ask the launcher to place the widget: the launcher
  /// supports it and no widget is placed yet.
  Future<bool> canAddWidget();

  /// Asks the launcher to place the widget; the user confirms there.
  Future<void> addWidget();
}
