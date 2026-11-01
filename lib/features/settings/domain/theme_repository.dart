/// Where the chosen light/dark mode is kept.
abstract interface class ThemeRepository {
  /// The saved mode (`system`, `light` or `dark`), or null if none was
  /// chosen yet.
  Future<String?> load();

  Future<void> save(String mode);
}
