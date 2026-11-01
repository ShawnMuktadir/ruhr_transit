import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/onboarding/presentation/onboarding_cubit.dart';

import '../../../helpers/fake_settings.dart';

void main() {
  test('complete shows the app and saves the flag', () async {
    final repository = FakeOnboardingRepository();
    final cubit = OnboardingCubit(repository, completed: false)..complete();
    await pumpEventQueue();

    expect(cubit.state, isTrue);
    expect(repository.completed, isTrue);
  });

  test('starts with the stored flag', () {
    final repository = FakeOnboardingRepository(completed: true);

    expect(OnboardingCubit(repository, completed: true).state, isTrue);
  });
}
