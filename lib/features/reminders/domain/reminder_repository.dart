import 'package:ruhr_transit/features/reminders/domain/reminder.dart';

/// The reminders that are set, on the device. Read by the app and by the
/// alarm while the app is closed.
abstract interface class ReminderRepository {
  Future<List<Reminder>> load();
  Future<void> save(List<Reminder> reminders);
}

/// Makes the reminder come at a time, also when the app is closed or after
/// a reboot. On Android an alarm wakes the app, which checks the delay
/// first; iOS lets no app run at a set time, so there the notification
/// itself is scheduled.
abstract interface class ReminderAlarms {
  /// Replaces an alarm with the same [id]. Without [exact], Android may
  /// delay it by some minutes to save battery.
  Future<void> schedule(int id, DateTime at, {required bool exact});
  Future<void> cancel(int id);
}

/// The notifications and the permissions they need.
abstract interface class ReminderNotifier {
  /// Asks for the notification permission if needed (Android 13+, iOS).
  Future<bool> ensurePermission();

  /// Whether alarms may be on time (Android 12+: "Alarms & reminders").
  /// Always on iOS.
  Future<bool> canBeExact();

  /// Opens the system page for "Alarms & reminders".
  Future<void> requestExact();

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    ReminderOpening? opens,

    /// When the system shows it; null shows it now.
    DateTime? at,
  });

  /// What the notification that started the app opens, if it was started
  /// that way.
  Future<ReminderOpening?> launched();

  /// What tapped notifications open while the app is running.
  Stream<ReminderOpening> get opened;

  Future<void> cancel(int id);
}
