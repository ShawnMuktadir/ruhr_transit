import 'dart:convert';

import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/favourites/data/stop_json.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Key of the widget data, read by `DepartureWidgetProvider.kt`. Versioned,
/// so a format change cannot be misread by a widget of an older format.
const widgetBoardKey = 'widget_board_v1';

/// More than the 3 rows the widget shows, so it still has departures left
/// after the first ones have left.
const maxWidgetDepartures = 10;

/// The widget data as JSON. Times are epoch milliseconds, which Kotlin
/// compares with `System.currentTimeMillis()` without parsing dates.
/// Departures are sorted by when they actually leave, so the widget can
/// skip the ones that have left and show the next 3.
String encodeWidgetBoard(Stop stop, DepartureBoard? board) {
  final departures = [...?board?.departures]
    ..sort((a, b) => _leaves(a).compareTo(_leaves(b)));
  return jsonEncode({
    'stop': stopToJson(stop),
    'fetchedAt': board?.fetchedAt.millisecondsSinceEpoch,
    'departures': [
      for (final departure in departures.take(maxWidgetDepartures))
        {
          'line': departure.line,
          'destination': departure.destination,
          'plannedTime': departure.plannedTime.millisecondsSinceEpoch,
          'estimatedTime': departure.estimatedTime?.millisecondsSinceEpoch,
          'isCancelled': departure.isCancelled,
        },
    ],
  });
}

/// The stop in [encodeWidgetBoard] output, or null if [raw] is missing or
/// unreadable.
Stop? widgetStopFromJson(String? raw) {
  if (raw == null) return null;
  try {
    return switch (jsonDecode(raw)) {
      {'stop': final Object stop} => stopFromJson(stop),
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

DateTime _leaves(Departure departure) =>
    departure.estimatedTime ?? departure.plannedTime;
