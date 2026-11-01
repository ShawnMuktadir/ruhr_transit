import 'dart:async';

import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

/// Hand-written fake that records what the app asked the widget to show.
class FakeWidgetSync implements WidgetSync {
  final List<(Stop, DepartureBoard?)> shown = [];
  final List<(String, DepartureBoard)> fetched = [];

  /// Add a stop to simulate a widget tap. Tests do not close it: nothing
  /// waits for it to finish.
  // ignore: close_sinks
  final StreamController<Stop> taps = StreamController.broadcast();

  Stop? launched;
  bool canAdd = false;
  int addCount = 0;

  @override
  Future<void> showStop(Stop stop, {DepartureBoard? board}) async =>
      shown.add((stop, board));

  @override
  Future<void> boardFetched(String stopId, DepartureBoard board) async =>
      fetched.add((stopId, board));

  @override
  Future<Stop?> launchedStop() async => launched;

  @override
  Stream<Stop> get openedStops => taps.stream;

  @override
  Future<bool> canAddWidget() async => canAdd;

  @override
  Future<void> addWidget() async => addCount++;
}
