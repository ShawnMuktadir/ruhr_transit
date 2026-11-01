/// Remembers whether the first-launch flow was completed.
abstract interface class OnboardingRepository {
  Future<bool> isCompleted();

  Future<void> markCompleted();
}
