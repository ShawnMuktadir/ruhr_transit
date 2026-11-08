import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

/// [WidgetSync] where the app has no home-screen widget: iOS, until it gets
/// a WidgetKit one. The app hides "show on widget" there.
class NoWidgetSync implements WidgetSync {
  const NoWidgetSync();

  @override
  bool get isAvailable => false;

  @override
  Future<void> showStop(Stop stop, {DepartureBoard? board}) async {}

  @override
  Future<void> boardFetched(String stopId, DepartureBoard board) async {}

  @override
  Future<Stop?> launchedStop() async => null;

  @override
  Stream<Stop> get openedStops => const Stream.empty();

  @override
  Future<bool> canAddWidget() async => false;

  @override
  Future<void> addWidget() async {}
}
