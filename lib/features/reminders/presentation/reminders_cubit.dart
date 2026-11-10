import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';

/// How setting a reminder ended.
enum ReminderOutcome {
  set,

  /// Set, but Android may deliver it some minutes late.
  setInexact,

  /// The notification permission was refused.
  denied,

  /// The time has passed.
  tooLate,
  failed,
}

/// The reminders that are set. The state is sorted, the next one first.
class RemindersCubit extends Cubit<List<Reminder>> {
  RemindersCubit(
    this._reminders,
    this._alarms,
    this._notifier, {
    Future<void> Function()? openAppSettings,
    DateTime Function()? now,
  }) : _openAppSettings = openAppSettings,
       _now = now ?? DateTime.now,
       super(const []) {
    unawaited(_start());
  }

  final ReminderRepository _reminders;
  final ReminderAlarms _alarms;
  final ReminderNotifier _notifier;
  final Future<void> Function()? _openAppSettings;
  final DateTime Function() _now;

  /// Android drops alarms when the app is force-stopped; setting them again
  /// on every start brings them back.
  Future<void> _start() async {
    await load();
    final exact = state.isEmpty ? false : await _notifier.canBeExact();
    for (final reminder in state) {
      await _schedule(reminder, exact: exact);
    }
  }

  /// Reads what is set, as an alarm may have changed it in the background,
  /// and forgets reminders whose ride has left.
  Future<void> load() async {
    final saved = await _reminders.load();
    final now = _now();
    final current = [
      for (final reminder in saved)
        if (reminder.departure.isAfter(now)) reminder,
    ];
    if (current.length != saved.length) await _reminders.save(current);
    _emit(current);
  }

  /// The set reminder for [journey], if any.
  Reminder? reminderFor(Journey journey) {
    final key = Reminder.keyOf(journey);
    return state.where((reminder) => reminder.key == key).firstOrNull;
  }

  /// Which reminders still lie ahead for [journey].
  List<Duration> leadsFor(Journey journey) {
    final leaveAt = journey.departure.time;
    final now = _now();
    return [
      for (final lead in reminderLeads)
        if (leaveAt.subtract(lead).isAfter(now)) lead,
    ];
  }

  /// The set reminder for [departure] at [stop], if any.
  Reminder? reminderForDeparture(Departure departure, Stop stop) {
    final key = Reminder.keyOfDeparture(departure, stop);
    return state.where((reminder) => reminder.key == key).firstOrNull;
  }

  /// Which reminders still lie ahead of a departure at [time].
  List<Duration> leadsBefore(DateTime time) {
    final now = _now();
    return [
      for (final lead in reminderLeads)
        if (time.subtract(lead).isAfter(now)) lead,
    ];
  }

  Future<ReminderOutcome> add(
    Journey journey, {
    required Duration lead,
    required String languageCode,
    required bool use24HourFormat,
    TripQuery? query,
  }) => _add(
    (id) => Reminder.forJourney(
      journey,
      id: id,
      lead: lead,
      languageCode: languageCode,
      use24HourFormat: use24HourFormat,
      query: query,
    ),
  );

  Future<ReminderOutcome> addForDeparture(
    Departure departure,
    Stop stop, {
    required Duration lead,
    required String languageCode,
    required bool use24HourFormat,
  }) => _add(
    (id) => Reminder.forDeparture(
      departure,
      stop,
      id: id,
      lead: lead,
      languageCode: languageCode,
      use24HourFormat: use24HourFormat,
    ),
  );

  Future<ReminderOutcome> _add(Reminder? Function(int id) make) async {
    if (!await _notifier.ensurePermission()) return ReminderOutcome.denied;
    final now = _now();
    // Fits Android's 32-bit alarm and notification ids.
    final reminder = make(now.millisecondsSinceEpoch ~/ 1000 % 0x7FFFFFFF);
    if (reminder == null || !reminder.notifyAt.isAfter(now)) {
      return ReminderOutcome.tooLate;
    }

    final exact = await _notifier.canBeExact();
    final others = [
      for (final other in state)
        if (other.key != reminder.key) other,
    ];
    final replaced = state.where((other) => other.key == reminder.key);
    for (final old in replaced) {
      await _alarms.cancel(old.id);
    }
    await _reminders.save([...others, reminder]);
    if (!await _schedule(reminder, exact: exact)) {
      await _reminders.save(others);
      _emit(others);
      return ReminderOutcome.failed;
    }
    _emit([...others, reminder]);
    return exact ? ReminderOutcome.set : ReminderOutcome.setInexact;
  }

  Future<void> remove(Reminder reminder) async {
    final others = [
      for (final other in state)
        if (other.id != reminder.id) other,
    ];
    await _alarms.cancel(reminder.id);
    await _notifier.cancel(reminder.id);
    await _reminders.save(others);
    _emit(others);
  }

  Future<void> allowExact() => _notifier.requestExact();

  Future<void> openAppSettings() async => _openAppSettings?.call();

  Future<bool> _schedule(Reminder reminder, {required bool exact}) async {
    try {
      await _alarms.schedule(reminder.id, reminder.notifyAt, exact: exact);
      return true;
    } on Object catch (e) {
      debugPrint('Could not set the alarm: $e');
      return false;
    }
  }

  void _emit(List<Reminder> reminders) {
    if (isClosed) return;
    emit([...reminders]..sort((a, b) => a.notifyAt.compareTo(b.notifyAt)));
  }
}
