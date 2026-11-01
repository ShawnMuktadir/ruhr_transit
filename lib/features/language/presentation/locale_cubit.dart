import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/features/language/domain/language_repository.dart';

/// The app's language. Null until the user chooses one: the app then
/// follows the device, like before there was a choice.
///
/// Provided above `MaterialApp`, which takes the locale from it, so a
/// change applies immediately without a restart.
class LocaleCubit extends Cubit<AppLanguage?> {
  /// [initial] is what [_repository] had stored when the app started.
  LocaleCubit(this._repository, {AppLanguage? initial}) : super(initial);

  final LanguageRepository _repository;

  void select(AppLanguage language) {
    if (language == state) return;
    emit(language);
    unawaited(
      _repository.save(language.code).catchError((Object e) {
        debugPrint('Could not save the language: $e');
      }),
    );
  }

  /// Picks up a language set outside the app, i.e. in Android's per-app
  /// language settings. Called when the device's locales change.
  Future<void> refresh() async {
    final language = AppLanguages.byCode(await _repository.load());
    if (language != null && !isClosed) select(language);
  }
}
