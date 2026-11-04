import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';
import 'package:ruhr_transit/core/widgets/clock_time.dart';
import 'package:ruhr_transit/features/reminders/domain/reminder.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';

/// In the trip details: sets a reminder to leave for [journey], or shows
/// the one that is set. Nothing for a walk alone or when it is too late;
/// nothing where no [RemindersCubit] is provided (tests of a single page).
class ReminderTile extends StatelessWidget {
  const ReminderTile(this.journey, {super.key});

  final Journey journey;

  @override
  Widget build(BuildContext context) {
    if (Reminder.keyOf(journey) == null) return const SizedBox.shrink();
    try {
      context.read<RemindersCubit>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final cubit = context.watch<RemindersCubit>();
    if (cubit.reminderFor(journey) case final reminder?) {
      return ListCard(
        child: ListTile(
          leading: Icon(
            Icons.notifications_active,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            l10n.reminderSetFor(formatClockTime(context, reminder.notifyAt)),
          ),
          subtitle: Text(l10n.reminderLeadOption(reminder.lead.inMinutes)),
          trailing: IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.reminderRemove,
            onPressed: () => unawaited(cubit.remove(reminder)),
          ),
        ),
      );
    }
    final leads = cubit.leadsFor(journey);
    if (leads.isEmpty) return const SizedBox.shrink();
    return ListCard(
      child: ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: Text(l10n.reminderAdd),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => unawaited(_choose(context, leads)),
      ),
    );
  }

  Future<void> _choose(BuildContext context, List<Duration> leads) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RemindersCubit>();
    final languageCode = Localizations.localeOf(context).languageCode;
    final use24HourFormat = MediaQuery.alwaysUse24HourFormatOf(context);
    final messenger = ScaffoldMessenger.of(context);
    final lead = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.reminderSheetTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            for (final lead in leads)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(l10n.reminderLeadOption(lead.inMinutes)),
                onTap: () => Navigator.of(context).pop(lead),
              ),
          ],
        ),
      ),
    );
    if (lead == null) return;

    final outcome = await cubit.add(
      journey,
      lead: lead,
      languageCode: languageCode,
      use24HourFormat: use24HourFormat,
    );
    final (String message, SnackBarAction? action) = switch (outcome) {
      ReminderOutcome.set => (l10n.reminderAdded, null),
      ReminderOutcome.setInexact => (
        l10n.reminderInexact,
        SnackBarAction(
          label: l10n.reminderAllowExact,
          onPressed: () => unawaited(cubit.allowExact()),
        ),
      ),
      ReminderOutcome.denied => (
        l10n.reminderDenied,
        SnackBarAction(
          label: l10n.actionSettings,
          onPressed: () => unawaited(cubit.openAppSettings()),
        ),
      ),
      ReminderOutcome.tooLate => (l10n.reminderTooLate, null),
      ReminderOutcome.failed => (l10n.reminderFailed, null),
    };
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), action: action));
  }
}
