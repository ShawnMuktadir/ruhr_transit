import 'package:ruhr_transit/features/onboarding/domain/onboarding_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  const OnboardingRepositoryImpl(this._preferences);

  static const storageKey = 'onboarding_completed_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<bool> isCompleted() async =>
      await _preferences.getBool(storageKey) ?? false;

  @override
  Future<void> markCompleted() => _preferences.setBool(storageKey, true);
}
