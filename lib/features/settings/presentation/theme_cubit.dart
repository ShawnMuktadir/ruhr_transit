import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/features/settings/domain/theme_repository.dart';

/// Light, dark or following Android. Provided above `MaterialApp`, which
/// takes its theme mode from it, so a change applies at once.
class ThemeCubit extends Cubit<ThemeMode> {
  /// [initial] is what [_repository] had stored when the app started.
  ThemeCubit(this._repository, {ThemeMode initial = ThemeMode.system})
    : super(initial);

  final ThemeRepository _repository;

  /// The stored mode, read before the app starts. Unknown values (e.g.
  /// from a newer version) fall back to following the system.
  static ThemeMode parse(String? stored) =>
      ThemeMode.values.where((mode) => mode.name == stored).firstOrNull ??
      ThemeMode.system;

  void select(ThemeMode mode) {
    if (mode == state) return;
    emit(mode);
    unawaited(
      _repository.save(mode.name).catchError((Object e) {
        debugPrint('Could not save the theme: $e');
      }),
    );
  }
}
