import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/widget_sync/data/widget_board_json.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

/// [WidgetSync] through the home_widget plugin, which stores the data where
/// the Kotlin widget reads it and tells the widget to redraw.
class HomeWidgetSync implements WidgetSync {
  const HomeWidgetSync();

  /// The `AppWidgetProvider` in `android/app/src/main/kotlin`.
  static const androidProvider =
      'de.muktadir.ruhrtransit.DepartureWidgetProvider';

  /// Host of the URI the widget opens the app with, e.g.
  /// `ruhrtransit://departures?stopId=de:05911:5194`.
  static const launchHost = 'departures';

  @override
  bool get isAvailable => true;

  @override
  Future<void> showStop(Stop stop, {DepartureBoard? board}) =>
      _quietly('show stop', () => _write(stop, board));

  @override
  Future<void> boardFetched(String stopId, DepartureBoard board) =>
      _quietly('update board', () async {
        final stop = await _shownStop();
        if (stop?.id == stopId) await _write(stop!, board);
      });

  @override
  Future<Stop?> launchedStop() async {
    try {
      return await _stopFor(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } on Exception catch (e) {
      debugPrint('Widget sync: could not read launch: $e');
      return null;
    }
  }

  @override
  Stream<Stop> get openedStops => HomeWidget.widgetClicked
      .asyncMap(_stopFor)
      .where((s) => s != null)
      .cast();

  @override
  Future<bool> canAddWidget() async {
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      return (await HomeWidget.getInstalledWidgets()).isEmpty;
    } on Exception catch (e) {
      debugPrint('Widget sync: could not check widgets: $e');
      return false;
    }
  }

  @override
  Future<void> addWidget() => _quietly(
    'add widget',
    () => HomeWidget.requestPinWidget(qualifiedAndroidName: androidProvider),
  );

  Future<void> _write(Stop stop, DepartureBoard? board) async {
    await HomeWidget.saveWidgetData(
      widgetBoardKey,
      encodeWidgetBoard(stop, board),
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
  }

  Future<Stop?> _shownStop() async => widgetStopFromJson(
    await HomeWidget.getWidgetData<String>(widgetBoardKey),
  );

  /// The widget's stop if [uri] opens its board. The URI carries the stop
  /// ID, so a tap on an outdated widget cannot open another stop.
  Future<Stop?> _stopFor(Uri? uri) async {
    if (uri == null || uri.host != launchHost) return null;
    final stop = await _shownStop();
    return stop?.id == uri.queryParameters['stopId'] ? stop : null;
  }

  Future<void> _quietly(String action, Future<void> Function() run) async {
    try {
      await run();
    } on Exception catch (e) {
      debugPrint('Widget sync: could not $action: $e');
    }
  }
}
