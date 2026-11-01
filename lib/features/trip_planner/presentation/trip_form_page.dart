import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/clock_time.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_page.dart';

/// Composition root of the trip form; [TripFormView] is what tests pump.
class TripFormPage extends StatelessWidget {
  const TripFormPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TripFormCubit(),
      child: const TripFormView(),
    );
  }
}

class TripFormView extends StatelessWidget {
  const TripFormView({this.pickStop = StopPicker.pick, super.key});

  /// Opens the stop picker; tests replace it.
  final Future<Stop?> Function(BuildContext context, {required String title})
  pickStop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TripFormCubit>();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tripTitle)),
      body: BlocBuilder<TripFormCubit, TripFormState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card.outlined(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _StopField(
                          label: l10n.tripFrom,
                          placeholder: l10n.tripChooseFrom,
                          icon: Icons.trip_origin,
                          stop: state.from,
                          onTap: () async {
                            final stop = await pickStop(
                              context,
                              title: l10n.tripChooseFrom,
                            );
                            if (stop != null) cubit.setFrom(stop);
                          },
                        ),
                        const Divider(height: 1, indent: 56),
                        _StopField(
                          label: l10n.tripTo,
                          placeholder: l10n.tripChooseTo,
                          icon: Icons.place,
                          stop: state.to,
                          onTap: () async {
                            final stop = await pickStop(
                              context,
                              title: l10n.tripChooseTo,
                            );
                            if (stop != null) cubit.setTo(stop);
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.swap_vert),
                    tooltip: l10n.tripSwap,
                    onPressed: state.from == null && state.to == null
                        ? null
                        : cubit.swap,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _TimeChooser(state.time),
            const SizedBox(height: 24),
            if (state.isSameStop)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  l10n.tripSameStop,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton.icon(
              icon: const Icon(Icons.search),
              label: Text(l10n.tripSearch),
              onPressed: switch (state.query) {
                final query? => () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TripResultsPage(query: query),
                  ),
                ),
                null => null,
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}

class _StopField extends StatelessWidget {
  const _StopField({
    required this.label,
    required this.placeholder,
    required this.icon,
    required this.stop,
    required this.onTap,
  });

  final String label;
  final String placeholder;
  final IconData icon;
  final Stop? stop;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(label, style: theme.textTheme.labelMedium),
      subtitle: Text(
        stop?.fullName ?? placeholder,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          color: stop == null ? theme.colorScheme.onSurfaceVariant : null,
        ),
      ),
      onTap: onTap,
    );
  }
}

enum _TimeKind { now, depart, arrive }

/// Now / depart / arrive, and the date and time for the latter two.
class _TimeChooser extends StatelessWidget {
  const _TimeChooser(this.time);

  final TripTime time;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TripFormCubit>();
    final (kind, chosen) = switch (time) {
      LeaveNow() => (_TimeKind.now, null),
      DepartAt(:final time) => (_TimeKind.depart, time),
      ArriveBy(:final time) => (_TimeKind.arrive, time),
    };

    void setTime(DateTime value) => kind == _TimeKind.arrive
        ? cubit.arriveBy(value)
        : cubit.departAt(value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_TimeKind>(
          segments: [
            ButtonSegment(value: _TimeKind.now, label: Text(l10n.tripNow)),
            ButtonSegment(
              value: _TimeKind.depart,
              label: Text(l10n.tripDepartAt),
            ),
            ButtonSegment(
              value: _TimeKind.arrive,
              label: Text(l10n.tripArriveBy),
            ),
          ],
          selected: {kind},
          onSelectionChanged: (selection) => switch (selection.single) {
            _TimeKind.now => cubit.leaveNow(),
            _TimeKind.depart => cubit.departAt(),
            _TimeKind.arrive => cubit.arriveBy(),
          },
        ),
        if (chosen != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    MaterialLocalizations.of(context).formatMediumDate(chosen),
                  ),
                  onPressed: () async {
                    final today = DateUtils.dateOnly(DateTime.now());
                    final date = await showDatePicker(
                      context: context,
                      initialDate: chosen.isBefore(today) ? today : chosen,
                      firstDate: today,
                      // Well within EFA's timetable period.
                      lastDate: today.add(const Duration(days: 30)),
                    );
                    if (date == null) return;
                    setTime(
                      DateTime(
                        date.year,
                        date.month,
                        date.day,
                        chosen.hour,
                        chosen.minute,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(formatClockTime(context, chosen.toUtc())),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(chosen),
                    );
                    if (picked == null) return;
                    setTime(
                      DateTime(
                        chosen.year,
                        chosen.month,
                        chosen.day,
                        picked.hour,
                        picked.minute,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
