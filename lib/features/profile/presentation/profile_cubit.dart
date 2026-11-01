import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';
import 'package:ruhr_transit/features/profile/domain/profile_repository.dart';

class ProfileState {
  const ProfileState({
    this.isLoading = true,
    this.displayName,
    this.auth = const SignedOut(),
    this.saveFailed = false,
  });

  final bool isLoading;
  final String? displayName;
  final AuthState auth;

  /// The last save did not work; the page says so.
  final bool saveFailed;

  ProfileState copyWith({
    bool? isLoading,
    String? Function()? displayName,
    AuthState? auth,
    bool? saveFailed,
  }) => ProfileState(
    isLoading: isLoading ?? this.isLoading,
    displayName: displayName == null ? this.displayName : displayName(),
    auth: auth ?? this.auth,
    saveFailed: saveFailed ?? this.saveFailed,
  );
}

/// The local display name and the sign-in state.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._profile, this._auth) : super(const ProfileState()) {
    _authSubscription = _auth.watch().listen(
      (auth) => emit(state.copyWith(auth: auth)),
    );
    unawaited(_load());
  }

  final ProfileRepository _profile;
  final AuthRepository _auth;
  late final StreamSubscription<AuthState> _authSubscription;

  Future<void> _load() async {
    String? name;
    try {
      name = await _profile.loadDisplayName();
    } on Object catch (e) {
      // Shown as "no name"; the user can set one again.
      debugPrint('Could not read the display name: $e');
    }
    if (!isClosed) {
      emit(state.copyWith(isLoading: false, displayName: () => name));
    }
  }

  /// Saves [name]; blank removes it. Returns whether it worked.
  Future<bool> saveDisplayName(String name) async {
    final trimmed = name.trim();
    try {
      await _profile.saveDisplayName(trimmed);
    } on Object catch (e) {
      debugPrint('Could not save the display name: $e');
      if (!isClosed) emit(state.copyWith(saveFailed: true));
      return false;
    }
    if (!isClosed) {
      emit(
        state.copyWith(
          displayName: () => trimmed.isEmpty ? null : trimmed,
          saveFailed: false,
        ),
      );
    }
    return true;
  }

  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> close() {
    unawaited(_authSubscription.cancel());
    return super.close();
  }
}
