import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ruhr_transit/features/favourites/data/stop_json.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:timezone/timezone.dart' as tz;

/// [ReminderNotifier] through flutter_local_notifications, on Android and
/// iOS. On Android it shows notifications at once, as the alarm decides the
/// timing; on iOS the system shows them at their time.
class LocalReminderNotifier implements ReminderNotifier {
  LocalReminderNotifier();

  static const _channelId = 'departure_reminders';

  /// Monochrome, as Android draws the status bar icon from its shape only.
  static const _icon = 'ic_notification';

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<ReminderOpening>.broadcast();

  /// Once, also when several calls arrive before it has finished.
  late final Future<void> _ready = _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings(_icon),
      // Asked for when the first reminder is set, not at the start.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    ),
    onDidReceiveNotificationResponse: (response) {
      if (_read(response.payload) case final opening?) _taps.add(opening);
    },
  );

  static String _write(ReminderOpening opening) => jsonEncode({
    'key': opening.key,
    'searchFrom': opening.searchFrom.toUtc().toIso8601String(),
    if (opening.stop case final stop?) 'stop': stopToJson(stop),
    if (opening.from case final stop?) 'from': stopToJson(stop),
    if (opening.to case final stop?) 'to': stopToJson(stop),
  });

  /// The notification's payload; null when there is none or it is unreadable.
  static ReminderOpening? _read(String? payload) {
    if (payload == null) return null;
    try {
      if (jsonDecode(payload)
          case {
                'key': final String key,
                'searchFrom': final String searchFrom,
              } &&
              final Map<String, Object?> json) {
        Stop? stop(String name) =>
            json[name] == null ? null : stopFromJson(json[name]);
        return ReminderOpening(
          key: key,
          searchFrom: DateTime.parse(searchFrom),
          stop: stop('stop'),
          from: stop('from'),
          to: stop('to'),
        );
      }
    } on FormatException catch (e) {
      debugPrint('Unreadable reminder notification: $e');
    }
    return null;
  }

  @override
  Future<ReminderOpening?> launched() async {
    await _ready;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return _read(details.notificationResponse?.payload);
  }

  @override
  Stream<ReminderOpening> get opened => _taps.stream;

  Future<T?> _platform<T extends FlutterLocalNotificationsPlatform>() async {
    await _ready;
    return _plugin.resolvePlatformSpecificImplementation<T>();
  }

  @override
  Future<bool> ensurePermission() async {
    if (await _platform<AndroidFlutterLocalNotificationsPlugin>()
        case final android?) {
      if (await android.areNotificationsEnabled() ?? false) return true;
      return await android.requestNotificationsPermission() ?? false;
    }
    // Asks only the first time; later answers the user's choice.
    final ios = await _platform<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  /// Only Android delays notifications to save battery.
  @override
  Future<bool> canBeExact() async {
    final android = await _platform<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return await android.canScheduleExactNotifications() ?? false;
  }

  @override
  Future<void> requestExact() async {
    final android = await _platform<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
    ReminderOpening? opens,
    DateTime? at,
  }) async {
    await _ready;
    final payload = switch (opens) {
      final opening? => _write(opening),
      null => null,
    };
    final details = NotificationDetails(
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
      iOS: const DarwinNotificationDetails(),
    );
    if (at == null) {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: details,
      );
      return;
    }
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      payload: payload,
      // An instant, so UTC works without the time zone database.
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _ready;
    await _plugin.cancel(id: id);
  }
}
