import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/onboarding/data/onboarding_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late OnboardingRepositoryImpl repository;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    repository = OnboardingRepositoryImpl(SharedPreferencesAsync());
  });

  test('is not completed on first launch', () async {
    expect(await repository.isCompleted(), isFalse);
  });

  test('stays completed once marked', () async {
    await repository.markCompleted();

    expect(await repository.isCompleted(), isTrue);
    // A new instance, as after a restart, reads the same flag.
    expect(
      await OnboardingRepositoryImpl(SharedPreferencesAsync()).isCompleted(),
      isTrue,
    );
  });
}
