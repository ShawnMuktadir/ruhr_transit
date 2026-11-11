import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A user setting kept as text under one key in shared preferences, e.g.
/// which means of transport trips leave out.
class SettingStore<T> {
  const SettingStore(
    this._preferences, {
    required this.key,
    required this.defaultValue,
    required this.fromText,
    required this.toText,
  });

  final SharedPreferencesAsync _preferences;

  /// Versioned, e.g. `trip_means_excluded_v1`.
  final String key;

  /// What applies until the user changes it, and when the saved text can't
  /// be read.
  final T defaultValue;
  final T? Function(String text) fromText;
  final String Function(T value) toText;

  Future<T> load() async {
    final text = await _preferences.getString(key);
    if (text == null) return defaultValue;
    return fromText(text) ?? defaultValue;
  }

  Future<void> save(T value) => _preferences.setString(key, toText(value));
}

/// The setting as a cubit: the state is its value. Starts with the default
/// and reads the saved value in the background; a change made before that
/// arrives wins.
class SettingCubit<T> extends Cubit<T> {
  SettingCubit(this._store) : super(_store.defaultValue) {
    unawaited(_load());
  }

  final SettingStore<T> _store;
  bool _changed = false;

  Future<void> _load() async {
    try {
      final saved = await _store.load();
      if (!_changed && !isClosed) emit(saved);
    } on Exception catch (e) {
      debugPrint('Could not read setting ${_store.key}: $e');
    }
  }

  /// Applies [value] at once and saves it.
  Future<void> set(T value) async {
    _changed = true;
    emit(value);
    try {
      await _store.save(value);
    } on Exception catch (e) {
      // Still applies for this session.
      debugPrint('Could not save setting ${_store.key}: $e');
    }
  }
}
