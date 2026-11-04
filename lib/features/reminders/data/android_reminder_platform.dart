import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/reminders/data/reminder_repository_impl.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_worker.dart';
import 'package:ruhr_transit/features/trip_planner/data/efa_run_remote_source.dart';
import 'package:ruhr_transit/features/trip_planner/data/vehicle_run_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Runs in a background isolate when an alarm fires, usually with the app
/// closed, so it builds what it needs itself instead of using get_it.
@pragma('vm:entry-point')
Future<void> reminderAlarmFired(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final worker = ReminderWorker(
    reminders: ReminderRepositoryImpl(SharedPreferencesAsync()),
    alarms: const AndroidReminderAlarms(),
    notifier: AndroidReminderNotifier(),
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

/// [ReminderNotifier] through flutter_local_notifications. Only shows
/// notifications at once: the timing is the alarm's.
class AndroidReminderNotifier implements ReminderNotifier {
  AndroidReminderNotifier();

  static const _channelId = 'departure_reminders';

  /// Monochrome, as Android draws the status bar icon from its shape only.
  static const _icon = 'ic_notification';

  final _plugin = FlutterLocalNotificationsPlugin();
  var _initialized = false;

  Future<AndroidFlutterLocalNotificationsPlugin?> _android() async {
    if (!_initialized) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_icon),
        ),
      );
      _initialized = true;
    }
    return _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
  }

  @override
  Future<bool> ensurePermission() async {
    final android = await _android();
    if (await android?.areNotificationsEnabled() ?? false) return true;
    return await android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> canBeExact() async =>
      await (await _android())?.canScheduleExactNotifications() ?? false;

  @override
  Future<void> requestExact() async {
    await (await _android())?.requestExactAlarmsPermission();
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    await _android();
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.reminder,
          // The line, stop, platform and delay do not fit on one line.
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _android();
    await _plugin.cancel(id: id);
  }
}
