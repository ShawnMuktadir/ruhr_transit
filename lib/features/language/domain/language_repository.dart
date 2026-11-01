/// Where the chosen app language is kept.
abstract interface class LanguageRepository {
  /// The chosen language code, or null before the user chose one.
  Future<String?> load();

  Future<void> save(String languageCode);
}
