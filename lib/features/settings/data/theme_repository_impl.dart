import 'package:ruhr_transit/features/settings/domain/theme_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeRepositoryImpl implements ThemeRepository {
  const ThemeRepositoryImpl(this._preferences);

  static const storageKey = 'theme_mode_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> load() => _preferences.getString(storageKey);

  @override
  Future<void> save(String mode) => _preferences.setString(storageKey, mode);
}
