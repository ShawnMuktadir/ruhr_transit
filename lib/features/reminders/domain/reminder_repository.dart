import 'package:ruhr_transit/features/reminders/domain/reminder.dart';

/// The reminders that are set, on the device. Read by the app and by the
/// alarm while the app is closed.
abstract interface class ReminderRepository {
  Future<List<Reminder>> load();
  Future<void> save(List<Reminder> reminders);
}

/// Wakes the app at a time, also when it is closed or after a reboot.
abstract interface class ReminderAlarms {
  /// Replaces an alarm with the same [id]. Without [exact], Android may
  /// delay it by some minutes to save battery.
  Future<void> schedule(int id, DateTime at, {required bool exact});
  Future<void> cancel(int id);
}

/// The notifications and the permissions they need.
abstract interface class ReminderNotifier {
  /// Asks for the notification permission if needed (Android 13+).
  Future<bool> ensurePermission();

  /// Whether alarms may be on time (Android 12+: "Alarms & reminders").
  Future<bool> canBeExact();

  /// Opens the system page for "Alarms & reminders".
  Future<void> requestExact();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  });

  Future<void> cancel(int id);
}
