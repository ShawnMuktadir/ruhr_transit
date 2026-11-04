import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder_repository.dart';

class FakeReminderRepository implements ReminderRepository {
  FakeReminderRepository([List<Reminder> initial = const []])
    : saved = [...initial];

  List<Reminder> saved;

  @override
  Future<List<Reminder>> load() async => [...saved];

  @override
  Future<void> save(List<Reminder> reminders) async => saved = [...reminders];
}

class FakeReminderAlarms implements ReminderAlarms {
  /// id to (time, exact).
  final Map<int, (DateTime, bool)> scheduled = {};
  final List<int> cancelled = [];
  Error? error;

  @override
  Future<void> schedule(int id, DateTime at, {required bool exact}) async {
    if (error case final error?) throw error;
    scheduled[id] = (at, exact);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }
}

class FakeReminderNotifier implements ReminderNotifier {
  bool permission = true;
  bool exact = true;
  int exactRequests = 0;
  final List<({int id, String title, String body})> shown = [];
  final List<int> cancelled = [];

  @override
  Future<bool> ensurePermission() async => permission;

  @override
  Future<bool> canBeExact() async => exact;

  @override
  Future<void> requestExact() async => exactRequests++;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async => shown.add((id: id, title: title, body: body));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}
