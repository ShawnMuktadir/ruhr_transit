import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/features/onboarding/domain/onboarding_repository.dart';

/// Whether the first-launch flow is done. The app shows the flow until it
/// is, and goes straight to the main screen afterwards.
class OnboardingCubit extends Cubit<bool> {
  /// [completed] is what [_repository] had stored when the app started.
  OnboardingCubit(this._repository, {required bool completed})
    : super(completed);

  final OnboardingRepository _repository;

  void complete() {
    if (state) return;
    emit(true);
    unawaited(
      _repository.markCompleted().catchError((Object e) {
        // At worst the flow shows once more on the next launch.
        debugPrint('Could not save onboarding: $e');
      }),
    );
  }
}
