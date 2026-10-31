import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/departures/data/departure_cache.dart';
import 'package:ruhr_transit/features/departures/data/departure_json.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../helpers/fake_departure_repository.dart';

void main() {
  late SharedPreferencesAsync preferences;
  late DepartureCache cache;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = SharedPreferencesAsync();
    cache = DepartureCache(preferences, maxStops: 3);
  });

  DepartureBoard boardAt(int minute) => DepartureBoard([
    delayedRe16,
  ], fetchedAt: DateTime.utc(2026, 10, 25, 17, minute));

  Future<List<String>> savedStopIds() async {
    final raw = await preferences.getString(DepartureCache.storageKey);
    return (jsonDecode(raw!) as Map<String, Object?>).keys.toList();
  }

  group('JSON', () {
    test('keeps every field of a departure', () {
      for (final departure in [delayedRe16, cancelledRe11, movedU35]) {
        final json = departureToJson(departure);
        expect(departureToJson(departureFromJson(json)), json);
      }
    });

    test('reads times as UTC and modes by name', () {
      final departure = departureFromJson(departureToJson(delayedRe16));

      expect(departure.plannedTime, delayedRe16.plannedTime);
      expect(departure.plannedTime.isUtc, isTrue);
      expect(departure.estimatedTime, delayedRe16.estimatedTime);
      expect(departure.mode, TransportMode.train);
      expect(departureToJson(delayedRe16)['mode'], 'train');
    });

    test('optional fields may be missing; unknown modes are null', () {
      final departure = departureFromJson({
        'line': '349',
        'mode': 'hovercraft',
        'destination': 'Wattenscheid',
        'plannedTime': '2026-10-25T17:13:00.000Z',
      });

      expect(departure.mode, isNull);
      expect(departure.estimatedTime, isNull);
      expect(departure.platform, isNull);
      expect(departure.isCancelled, isFalse);
      expect(departure.notes, isEmpty);
    });

    test('a missing required field is a FormatException', () {
      expect(
        () => departureFromJson({'line': '349', 'destination': 'X'}),
        throwsFormatException,
      );
      expect(
        () => boardFromJson({
          'fetchedAt': '2026-10-25T17:00:00.000Z',
          'departures': [
            departureToJson(delayedRe16),
            {'line': 'broken'},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  test('nothing saved is null', () async {
    expect(await cache.read('a'), isNull);
  });

  test('saves and reads a board per stop', () async {
    await cache.write('a', boardAt(1));
    await cache.write('b', DepartureBoard(const [], fetchedAt: boardTime));

    final a = await cache.read('a');
    expect(a?.fetchedAt, DateTime.utc(2026, 10, 25, 17, 1));
    expect(a?.departures.map(departureToJson), [departureToJson(delayedRe16)]);
    expect((await cache.read('b'))?.departures, isEmpty);
  });

  test('a new board replaces the old one of the same stop', () async {
    await cache.write('a', boardAt(1));
    await cache.write('a', boardAt(2));

    expect((await cache.read('a'))?.fetchedAt.minute, 2);
    expect(await savedStopIds(), ['a']);
  });

  test('stores everything in a versioned key', () async {
    await cache.write('a', boardAt(1));

    expect(await preferences.getKeys(), {'departure_boards_v1'});
  });

  test('keeps only the most recently saved stops', () async {
    await cache.write('a', boardAt(1));
    await cache.write('b', boardAt(2));
    await cache.write('c', boardAt(3));
    // Saving a again makes it the newest, so b is the oldest now.
    await cache.write('a', boardAt(4));
    await cache.write('d', boardAt(5));

    expect(await savedStopIds(), ['c', 'a', 'd']);
    expect(await cache.read('b'), isNull);
  });

  test('writes started together are all kept', () async {
    await Future.wait([
      cache.write('a', boardAt(1)),
      cache.write('b', boardAt(2)),
      cache.write('c', boardAt(3)),
    ]);

    expect(await savedStopIds(), ['a', 'b', 'c']);
  });

  test('unreadable data reads as nothing and is replaced', () async {
    for (final raw in ['not json', '[1,2]', '{"a":{"fetchedAt":42}}']) {
      await preferences.setString(DepartureCache.storageKey, raw);
      expect(await cache.read('a'), isNull, reason: raw);
    }

    await cache.write('b', boardAt(1));
    expect(await cache.read('b'), isNotNull);
  });

  test('a broken board does not affect the other stops', () async {
    await cache.write('a', boardAt(1));
    final raw = await preferences.getString(DepartureCache.storageKey);
    await preferences.setString(
      DepartureCache.storageKey,
      raw!.replaceFirst('{', '{"broken":{"departures":[]},'),
    );

    expect(await cache.read('broken'), isNull);
    expect(await cache.read('a'), isNotNull);
  });

  test('stores the departure fields by name', () async {
    await cache.write('a', DepartureBoard([movedU35], fetchedAt: boardTime));

    final raw = await preferences.getString(DepartureCache.storageKey);
    expect(raw, contains('"mode":"subway"'));
    expect(raw, contains('"plannedTime":"2026-10-25T17:35:00.000Z"'));
    expect(raw, contains('"plannedPlatform":"Gleis 4 (U)"'));
  });
}
