import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/clock_time.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_cubit.dart';

/// All reminders that are set, under Settings: a reminder can be removed
/// here without finding its trip again.
class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.watch<RemindersCubit>();
    final reminders = cubit.state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.remindersTitle)),
      body: reminders.isEmpty
          ? CenteredMessage(l10n.remindersEmpty, icon: Icons.notifications_none)
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final Reminder reminder in reminders)
                  ListCard(
                    child: ListTile(
                      leading: const Icon(Icons.notifications_active),
                      title: Text(
                        l10n.reminderNotifyBody(
                          reminder.line,
                          reminder.stopName,
                          formatClockTime(context, reminder.departure),
                        ),
                      ),
                      subtitle: Text(
                        l10n.reminderSetFor(
                          formatClockTime(context, reminder.notifyAt),
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: l10n.reminderRemove,
                        onPressed: () => unawaited(cubit.remove(reminder)),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
