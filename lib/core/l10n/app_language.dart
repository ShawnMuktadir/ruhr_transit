import 'dart:ui';

/// A language the app is translated into.
class AppLanguage {
  const AppLanguage(this.code, this.nativeName);

  /// ISO 639-1 code, as in the ARB file name (`app_de.arb`).
  final String code;

  /// The language's name in itself, so everyone finds their own.
  final String nativeName;

  Locale get locale => Locale(code);

  @override
  String toString() => 'AppLanguage($code)';
}

/// The languages to choose from.
///
/// To add one: add `lib/core/l10n/arb/app_<code>.arb`, an entry here and a
/// `<locale>` in `android/app/src/main/res/xml/locales_config.xml`. A test
/// checks that all three agree.
abstract final class AppLanguages {
  /// German first: it is the fallback for unsupported device languages.
  static const all = [
    AppLanguage('de', 'Deutsch'),
    AppLanguage('en', 'English'),
  ];

  static AppLanguage get fallback => all.first;

  /// The language with [code] (e.g. `en`, or a tag like `en-GB`), or null if
  /// the app does not support it.
  static AppLanguage? byCode(String? code) {
    if (code == null) return null;
    final language = code.split(RegExp('[-_]')).first.toLowerCase();
    for (final candidate in all) {
      if (candidate.code == language) return candidate;
    }
    return null;
  }

  /// The first of the device's preferred [locales] the app supports,
  /// otherwise [fallback]. The same rule Flutter applies when no language
  /// was chosen yet.
  static AppLanguage forDevice(List<Locale> locales) {
    for (final locale in locales) {
      if (byCode(locale.languageCode) case final language?) return language;
    }
    return fallback;
  }
}
