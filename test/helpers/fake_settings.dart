import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:ruhr_transit/features/language/domain/language_repository.dart';
import 'package:ruhr_transit/features/onboarding/domain/onboarding_repository.dart';
import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';
import 'package:ruhr_transit/features/profile/domain/profile_repository.dart';
import 'package:ruhr_transit/features/settings/domain/theme_repository.dart';

/// In-memory language. [saved] is what the app last stored, or what
/// Android's per-app setting says.
class FakeLanguageRepository implements LanguageRepository {
  FakeLanguageRepository([this.saved]);

  String? saved;
  int saveCount = 0;

  @override
  Future<String?> load() async => saved;

  @override
  Future<void> save(String languageCode) async {
    saveCount++;
    saved = languageCode;
  }
}

class FakeOnboardingRepository implements OnboardingRepository {
  FakeOnboardingRepository({this.completed = false});

  bool completed;

  @override
  Future<bool> isCompleted() async => completed;

  @override
  Future<void> markCompleted() async => completed = true;
}

class FakeThemeRepository implements ThemeRepository {
  FakeThemeRepository([this.saved]);

  String? saved;

  @override
  Future<String?> load() async => saved;

  @override
  Future<void> save(String mode) async => saved = mode;
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([this.name]);

  String? name;

  /// When set, saving throws it.
  Exception? saveError;

  @override
  Future<String?> loadDisplayName() async => name;

  @override
  Future<void> saveDisplayName(String? name) async {
    if (saveError case final error?) throw error;
    final trimmed = name?.trim();
    this.name = trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Signed out like the app today, or signed in to test what a real
/// backend would show.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository([AuthState initial = const SignedOut()])
    : _state = initial;

  AuthState _state;
  final _changes = StreamController<AuthState>.broadcast();
  int signOutCalls = 0;

  @override
  Stream<AuthState> watch() async* {
    yield _state;
    yield* _changes.stream;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _state = const SignedOut();
    _changes.add(_state);
  }
}

/// What PackageInfo.fromPlatform would answer.
Future<PackageInfo> fakePackageInfo() async => PackageInfo(
  appName: 'RuhrTransit',
  packageName: 'de.muktadir.ruhrtransit',
  version: '1.0.0',
  buildNumber: '1',
);
