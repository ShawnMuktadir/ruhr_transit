import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/widget_sync/data/widget_board_json.dart';

import '../../../helpers/fake_departure_repository.dart';
import '../../../helpers/fake_stop_repository.dart';

void main() {
  Map<String, Object?> decode(String raw) =>
      jsonDecode(raw) as Map<String, Object?>;

  test('stores the stop, fetch time and departures as epoch millis', () {
    final json = decode(
      encodeWidgetBoard(
        bochumHbf,
        DepartureBoard([delayedRe16, cancelledRe11], fetchedAt: boardTime),
      ),
    );

    expect(json['fetchedAt'], boardTime.millisecondsSinceEpoch);
    expect((json['stop']! as Map)['fullName'], 'Bochum, Hbf');
    expect(json['departures'], [
      {
        'line': 'RE11',
        'destination': 'Kassel Bahnhof Wilhelmshöhe',
        'plannedTime': cancelledRe11.plannedTime.millisecondsSinceEpoch,
        'estimatedTime': null,
        'isCancelled': true,
      },
      {
        'line': 'RE16',
        'destination': 'Essen Hauptbahnhof',
        'plannedTime': delayedRe16.plannedTime.millisecondsSinceEpoch,
        'estimatedTime': delayedRe16.estimatedTime!.millisecondsSinceEpoch,
        'isCancelled': false,
      },
    ]);
  });

  test('sorts by actual leaving time and keeps at most 10', () {
    // RE16 is planned for 17:13 but leaves at 17:25, after RE11 at 17:24.
    final many = [
      for (var i = 0; i < 12; i++)
        Departure(
          line: 'B$i',
          destination: 'D',
          plannedTime: DateTime.utc(2026, 10, 25, 18, i),
        ),
      delayedRe16,
      cancelledRe11,
    ];
    final json = decode(
      encodeWidgetBoard(bochumHbf, DepartureBoard(many, fetchedAt: boardTime)),
    );

    final lines = [
      for (final d in json['departures']! as List) (d as Map)['line'],
    ];
    expect(lines, hasLength(maxWidgetDepartures));
    expect(lines.take(3), ['RE11', 'RE16', 'B0']);
  });

  test('a stop without a board yet has no departures', () {
    final json = decode(encodeWidgetBoard(bochumHbf, null));

    expect(json['fetchedAt'], isNull);
    expect(json['departures'], isEmpty);
  });

  test('reads the stop back', () {
    expect(widgetStopFromJson(encodeWidgetBoard(bochumHbf, null)), bochumHbf);
  });

  test('missing or unreadable data has no stop', () {
    for (final raw in [null, 'not json', '{}', '{"stop":{"id":"x"}}']) {
      expect(widgetStopFromJson(raw), isNull, reason: raw);
    }
  });
}
