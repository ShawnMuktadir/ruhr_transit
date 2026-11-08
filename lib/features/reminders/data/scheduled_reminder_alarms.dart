import 'dart:ui' show Locale;

import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_worker.dart';

/// [ReminderAlarms] for iOS, which lets no app run at a set time: the
/// notification itself is scheduled, with the departure known when it was
/// set. It does not move for later delays, but the time and delay in it
/// are refreshed whenever the app starts.
class ScheduledReminderAlarms implements ReminderAlarms {
  ScheduledReminderAlarms(
    this._reminders,
    this._notifier, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReminderRepository _reminders;
  final ReminderNotifier _notifier;
  final DateTime Function() _now;

  /// [exact] is ignored: iOS shows notifications on time.
  @override
  Future<void> schedule(int id, DateTime at, {required bool exact}) async {
    // Already shown, or too late to help.
    if (!at.isAfter(_now())) return;
    final reminders = await _reminders.load();
    final reminder = reminders.where((r) => r.id == id).firstOrNull;
    if (reminder == null) throw StateError('No reminder $id');
    final l10n = lookupAppLocalizations(Locale(reminder.languageCode));
    // Written for the moment it is shown.
    final (:title, :body) = reminderTexts(l10n, reminder, now: at);
    await _notifier.show(
      id: id,
      title: title,
      body: body,
      channelName: l10n.reminderChannel,
      channelDescription: l10n.reminderChannelDescription,
      opens: reminder.opening,
      at: at,
    );
  }

  @override
  Future<void> cancel(int id) => _notifier.cancel(id);
}
