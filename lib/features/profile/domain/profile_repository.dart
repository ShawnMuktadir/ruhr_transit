/// The user's profile on this device. Works without an account.
abstract interface class ProfileRepository {
  /// The display name, or null if none was set.
  Future<String?> loadDisplayName();

  /// Null or blank removes the name.
  Future<void> saveDisplayName(String? name);
}
