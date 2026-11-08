import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/reminders/data/local_reminder_notifier.dart';
import 'package:ruhr_transit/features/reminders/data/reminder_repository_impl.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_worker.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_run_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/vehicle_run_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lets alarms run the reminder check while the app is closed. Android
/// only: iOS has no such alarms (see `ScheduledReminderAlarms`).
Future<void> initializeReminderAlarms() async {
  if (defaultTargetPlatform != TargetPlatform.android) return;
  await AndroidAlarmManager.initialize();
}

/// Runs in a background isolate when an alarm fires, usually with the app
/// closed, so it builds what it needs itself instead of using get_it.
@pragma('vm:entry-point')
Future<void> reminderAlarmFired(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final worker = ReminderWorker(
    reminders: ReminderRepositoryImpl(SharedPreferencesAsync()),
    alarms: const AndroidReminderAlarms(),
    notifier: LocalReminderNotifier(),
    runs: VehicleRunRepositoryImpl(EfaRunRemoteSource(createEfaDio())),
  );
  await worker.fire(id);
}

/// [ReminderAlarms] through android_alarm_manager_plus. The only file that
/// knows about it.
class AndroidReminderAlarms implements ReminderAlarms {
  const AndroidReminderAlarms();

  @override
  Future<void> schedule(int id, DateTime at, {required bool exact}) async {
    final scheduled = await AndroidAlarmManager.oneShotAt(
      at.toLocal(),
      id,
      reminderAlarmFired,
      // Also in Android's battery saving, and after a reboot.
      allowWhileIdle: true,
      wakeup: true,
      exact: exact,
      rescheduleOnReboot: true,
    );
    if (!scheduled) throw StateError('Alarm $id was not scheduled');
  }

  @override
  Future<void> cancel(int id) => AndroidAlarmManager.cancel(id);
}
