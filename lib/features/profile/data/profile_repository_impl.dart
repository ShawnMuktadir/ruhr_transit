import 'package:ruhr_transit/features/profile/domain/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl(this._preferences);

  static const displayNameKey = 'profile_display_name_v1';

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> loadDisplayName() => _preferences.getString(displayNameKey);

  @override
  Future<void> saveDisplayName(String? name) {
    final trimmed = name?.trim();
    return trimmed == null || trimmed.isEmpty
        ? _preferences.remove(displayNameKey)
        : _preferences.setString(displayNameKey, trimmed);
  }
}
