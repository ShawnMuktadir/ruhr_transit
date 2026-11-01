import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ruhr_transit/features/language/domain/language_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Talks to `MainActivity`, which reads and sets Android's per-app language
/// (Settings > Apps > RuhrTransit > Language, Android 13+). Below Android 13
/// both calls answer null.
const appLocaleChannel = MethodChannel('de.muktadir.ruhrtransit/app_locale');

/// Keeps the language in shared preferences and in sync with Android's
/// per-app language.
///
/// On Android 13+ the per-app language is the source of truth, so a change
/// made in the system settings is not overridden by the app; it is also
/// what the native home-screen widget is drawn in. Older versions have no
/// per-app language, so only the saved preference counts there.
class LanguageRepositoryImpl implements LanguageRepository {
  const LanguageRepositoryImpl(
    this._preferences, {
    MethodChannel channel = appLocaleChannel,
  }) : _channel = channel;

  static const storageKey = 'app_language_v1';

  final SharedPreferencesAsync _preferences;
  final MethodChannel _channel;

  @override
  Future<String?> load() async =>
      await _invoke('get') ?? await _preferences.getString(storageKey);

  @override
  Future<void> save(String languageCode) async {
    await _preferences.setString(storageKey, languageCode);
    await _invoke('set', languageCode);
  }

  /// Android's answer, or null when there is none or the call failed: the
  /// saved preference still works without it.
  Future<String?> _invoke(String method, [String? argument]) async {
    try {
      return await _channel.invokeMethod<String>(method, argument);
    } on PlatformException catch (e) {
      debugPrint('App locale $method failed: $e');
    } on MissingPluginException {
      // Not on Android (tests, other platforms).
    }
    return null;
  }
}
