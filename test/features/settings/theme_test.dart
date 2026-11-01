import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/settings/data/theme_repository_impl.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../helpers/fake_settings.dart';

void main() {
  group('ThemeRepositoryImpl', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    test('nothing chosen yet is null; a choice survives a restart', () async {
      final repository = ThemeRepositoryImpl(SharedPreferencesAsync());
      expect(await repository.load(), isNull);

      await repository.save('dark');

      expect(
        await ThemeRepositoryImpl(SharedPreferencesAsync()).load(),
        'dark',
      );
    });
  });

  group('ThemeCubit', () {
    test('parse reads stored modes and falls back to the system', () {
      expect(ThemeCubit.parse('dark'), ThemeMode.dark);
      expect(ThemeCubit.parse('light'), ThemeMode.light);
      expect(ThemeCubit.parse(null), ThemeMode.system);
      // e.g. written by a newer version.
      expect(ThemeCubit.parse('sepia'), ThemeMode.system);
    });

    test('follows the system until something is chosen', () {
      expect(ThemeCubit(FakeThemeRepository()).state, ThemeMode.system);
    });

    test('select applies and saves the mode', () async {
      final repository = FakeThemeRepository();
      final cubit = ThemeCubit(repository)..select(ThemeMode.dark);
      await pumpEventQueue();

      expect(cubit.state, ThemeMode.dark);
      expect(repository.saved, 'dark');
    });

    test('selecting the current mode saves nothing', () async {
      final repository = FakeThemeRepository();
      ThemeCubit(repository, initial: ThemeMode.light).select(ThemeMode.light);
      await pumpEventQueue();

      expect(repository.saved, isNull);
    });
  });
}
