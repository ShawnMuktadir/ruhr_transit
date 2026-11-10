import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/storage/json_list_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late SharedPreferencesAsync preferences;
  late JsonListStore<int> store;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    preferences = SharedPreferencesAsync();
    store = JsonListStore(
      preferences,
      key: 'numbers_v1',
      // Like the real readers: null or a FormatException for a bad entry.
      fromJson: (json) => switch (json) {
        final int number when number >= 0 => number,
        int() => throw const FormatException('negative'),
        _ => null,
      },
      toJson: (number) => number,
    );
  });

  test('keeps a list', () async {
    await store.save([3, 1, 2]);
    expect(await store.load(), [3, 1, 2]);
  });

  test('nothing saved reads as empty', () async {
    expect(await store.load(), isEmpty);
  });

  test('an unreadable entry costs only itself', () async {
    await preferences.setString('numbers_v1', '[1, "x", -4, 2]');
    expect(await store.load(), [1, 2]);
  });

  test('an unreadable list reads as empty', () async {
    await preferences.setString('numbers_v1', '{not json');
    expect(await store.load(), isEmpty);
    await preferences.setString('numbers_v1', '{"a": 1}');
    expect(await store.load(), isEmpty);
  });

  test('an empty list removes the key', () async {
    await store.save([1]);
    await store.save([]);
    expect(await preferences.containsKey('numbers_v1'), isFalse);
  });
}
