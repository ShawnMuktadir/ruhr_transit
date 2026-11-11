import 'package:ruhr_transit/core/storage/setting_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether departure boards show cancelled departures (crossed out) or hide
/// them. On by default, so nothing disappears unexpectedly. Saved on the
/// phone; provided above `MaterialApp`.
class ShowCancelledCubit extends SettingCubit<bool> {
  ShowCancelledCubit(SharedPreferencesAsync preferences)
    : super(
        SettingStore(
          preferences,
          key: 'departures_show_cancelled_v1',
          defaultValue: true,
          fromText: bool.tryParse,
          toText: (show) => '$show',
        ),
      );
}
