import 'dart:ui' show Locale;

import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/platform_chip.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/trip_planner/domain/vehicle_run_repository.dart';

/// What happens when a reminder's alarm fires, usually with the app closed:
/// ask VRR for the ride's delay, then wait longer or notify.
class ReminderWorker {
  ReminderWorker({
    required ReminderRepository reminders,
    required ReminderAlarms alarms,
    required ReminderNotifier notifier,
    required VehicleRunRepository runs,
    DateTime Function()? now,
  }) : _reminders = reminders,
       _alarms = alarms,
       _notifier = notifier,
       _runs = runs,
       _now = now ?? DateTime.now;

  final ReminderRepository _reminders;
  final ReminderAlarms _alarms;
  final ReminderNotifier _notifier;
  final VehicleRunRepository _runs;
  final DateTime Function() _now;

  /// A delay shorter than this does not move the notification.
  static const minimumWait = Duration(minutes: 2);

  Future<void> fire(int id) async {
    final all = await _reminders.load();
    final index = all.indexWhere((reminder) => reminder.id == id);
    if (index < 0) return;
    final others = [...all]..removeAt(index);

    final reminder = all[index].withDeparture(await _departure(all[index]));
    final now = _now();

    // Fired too late to help, e.g. the phone was off.
    if (reminder.departure.isBefore(now)) {
      await _reminders.save(others);
      return;
    }

    // Delayed: come back when it is really time. Checks again then.
    if (reminder.notifyAt.difference(now) >= minimumWait) {
      await _reminders.save([...others, reminder]);
      await _alarms.schedule(
        id,
        reminder.notifyAt,
        exact: await _notifier.canBeExact(),
      );
      return;
    }

    final l10n = lookupAppLocalizations(Locale(reminder.languageCode));
    final (:title, :body) = reminderTexts(l10n, reminder, now: now);
    await _notifier.show(
      id: id,
      title: title,
      body: body,
      channelName: l10n.reminderChannel,
      channelDescription: l10n.reminderChannelDescription,
      opens: reminder.opening,
    );
    await _reminders.save(others);
  }

  /// The live departure; without one (no run, offline, stop not found) the
  /// last known time, so the reminder still comes.
  Future<DateTime> _departure(Reminder reminder) async {
    final key = reminder.runKey;
    if (key == null) return reminder.departure;
    switch (await _runs.run(key)) {
      case Ok(value: final run):
        final stop = run.indexOf(
          reminder.originStopId ?? key.stopId,
          parentId: reminder.originParentId,
        );
        return stop == null ? reminder.departure : run.stops[stop].departure;
      case Err():
        return reminder.departure;
    }
  }
}

/// The notification: "In 10 Min. losgehen" and "RE6 ab Bochum Hbf um 20:03
/// · Gleis 3 · 5 Min. später". The minutes count from now, as an alarm can
/// come late.
({String title, String body}) reminderTexts(
  AppLocalizations l10n,
  Reminder reminder, {
  required DateTime now,
}) {
  // Rounded up: an alarm fires a moment after its time, and a 10-minute
  // reminder should not say 9.
  final minutes = (reminder.leaveAt.difference(now).inSeconds + 59) ~/ 60;
  final delay = reminder.departure
      .difference(reminder.plannedDeparture)
      .inMinutes;
  final walk = reminder.walkBefore.inMinutes;
  return (
    title: minutes > 0
        ? l10n.reminderNotifyIn(minutes)
        : l10n.reminderNotifyNow,
    body: [
      l10n.reminderNotifyBody(
        reminder.line,
        reminder.stopName,
        reminderClock(reminder.departure, reminder.use24HourFormat),
      ),
      ?platformLabel(l10n, reminder.platform, mode: reminder.mode),
      if (delay > 0) l10n.departureLate(delay),
      if (walk > 0) l10n.tripWalk(walk),
    ].join(' · '),
  );
}

/// [time] in the phone's time zone, without a screen to ask for the format.
String reminderClock(DateTime time, bool use24HourFormat) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  if (use24HourFormat) return '${two(local.hour)}:${two(local.minute)}';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${two(local.minute)} ${local.hour < 12 ? 'AM' : 'PM'}';
}
