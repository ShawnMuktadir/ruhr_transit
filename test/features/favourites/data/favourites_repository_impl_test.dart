import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/features/favourites/data/favourites_repository_impl.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../helpers/fake_stop_repository.dart';

void main() {
  late SharedPreferencesAsync preferences;
  late FavouritesRepositoryImpl repository;

  setUp(() {
    // The plugin's documented way to test the async API without a device.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = SharedPreferencesAsync();
    repository = FavouritesRepositoryImpl(preferences);
  });

  Future<void> store(String raw) =>
      preferences.setString(FavouritesRepositoryImpl.storageKey, raw);

  test('nothing saved yet is an empty list', () async {
    expect(await repository.load(), isEmpty);
  });

  test('saves and loads stops with all fields, in order', () async {
    await repository.save([dortmundHbf, bochumHbf]);

    final loaded = await repository.load();

    expect(loaded, [dortmundHbf, bochumHbf]);
    final bochum = loaded.last;
    expect(bochum.name, 'Hbf');
    expect(bochum.fullName, 'Bochum, Hbf');
    expect(bochum.locality, 'Bochum');
    expect(bochum.latitude, 51.479466);
    expect(bochum.longitude, 7.223335);
    expect(bochum.modes, {
      TransportMode.train,
      TransportMode.subway,
      TransportMode.bus,
    });
    expect(loaded.first.locality, 'Dortmund');
  });

  test('saving an empty list removes all favourites', () async {
    await repository.save([bochumHbf]);
    await repository.save([]);

    expect(await repository.load(), isEmpty);
  });

  test('stores modes by name in a versioned key', () async {
    await repository.save([bochumHbf]);

    final raw = await preferences.getString('favourite_stops_v1');

    expect(raw, contains('"modes":["train","subway","bus"]'));
  });

  test('unreadable data gives an empty list instead of an error', () async {
    for (final raw in ['not json', '{"id":"x"}', '42']) {
      await store(raw);
      expect(await repository.load(), isEmpty, reason: raw);
    }
  });

  test('skips broken entries and keeps the others', () async {
    await store(
      '[{"id":"broken"},'
      '{"id":"de:05911:5194","name":"Hbf","fullName":"Bochum, Hbf",'
      '"latitude":51.48,"longitude":7.22,"modes":["bus","hovercraft"]}]',
    );

    final loaded = await repository.load();

    expect(loaded.map((s) => s.id), ['de:05911:5194']);
    // Unknown modes, e.g. written by a newer app version, are dropped.
    expect(loaded.single.modes, {TransportMode.bus});
    expect(loaded.single.locality, isNull);
  });

  test('integer coordinates are read as doubles', () async {
    await store(
      '[{"id":"a","name":"A","fullName":"T, A","latitude":51,"longitude":7}]',
    );

    final stop = (await repository.load()).single;

    expect(
      stop,
      const Stop(
        id: 'a',
        name: 'A',
        fullName: 'T, A',
        latitude: 51,
        longitude: 7,
      ),
    );
    expect(stop.latitude, isA<double>());
  });
}
