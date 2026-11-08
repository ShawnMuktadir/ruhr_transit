import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/connectivity/offline_banner.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/clock_time.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/line_badge.dart';
import 'package:ruhr_transit/core/widgets/platform_chip.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_state.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourite_stop_button.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminder_tile.dart';
import 'package:ruhr_transit/features/reminders/presentation/reminders_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/stop_actions.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

/// Composition root of the departure board: creates the cubit and starts
/// loading, then hands over to [DeparturesView], which tests can pump with
/// their own cubit.
class DeparturesPage extends StatelessWidget {
  const DeparturesPage({required this.stop, super.key});

  final Stop stop;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          DeparturesCubit(getIt<DepartureRepository>(), stop.id)..load(),
      child: DeparturesView(stop: stop, widgetSync: getIt<WidgetSync>()),
    );
  }
}

class DeparturesView extends StatelessWidget {
  const DeparturesView({
    required this.stop,
    required this.widgetSync,
    super.key,
  });

  final Stop stop;
  final WidgetSync widgetSync;

  Future<void> _showOnWidget(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // The board on screen, so the widget is filled right away.
    final board = switch (context.read<DeparturesCubit>().state) {
      DeparturesLoaded(:final departures, :final fetchedAt) => DepartureBoard(
        departures,
        fetchedAt: fetchedAt,
      ),
      _ => null,
    };
    await widgetSync.showStop(stop, board: board);
    final canAdd = await widgetSync.canAddWidget();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.widgetShown(stop.fullName)),
          action: canAdd
              ? SnackBarAction(
                  label: l10n.widgetAdd,
                  onPressed: widgetSync.addWidget,
                )
              : null,
        ),
      );
  }

  /// Retries what failed when the phone is back online.
  @override
  Widget build(BuildContext context) => OnReconnect(
    onReconnect: () {
      final cubit = context.read<DeparturesCubit>();
      switch (cubit.state) {
        case DeparturesFailed():
        case DeparturesLoaded(refreshFailure: _?):
          unawaited(cubit.refresh());
        case _:
      }
    },
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeparturesCubit>();
    return Scaffold(
      appBar: AppBar(
        title: Text(stop.fullName),
        actions: [
          FavouriteStopButton(stop),
          // Pull-to-refresh is not discoverable or usable for everyone.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
            onPressed: cubit.refresh,
          ),
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: () => _showOnWidget(context),
                child: Text(l10n.widgetShow),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: PlanFromStopButton(stop),
            ),
          ),
          Expanded(
            child: BlocConsumer<DeparturesCubit, DeparturesState>(
              listenWhen: (_, state) =>
                  state is DeparturesLoaded && state.refreshFailure != null,
              listener: (context, state) {
                final failure = (state as DeparturesLoaded).refreshFailure!;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(content: Text(failureMessage(l10n, failure))),
                  );
              },
              builder: (context, state) => switch (state) {
                DeparturesLoading() => const AppLoader(),
                DeparturesFailed(:final failure) => CenteredMessage(
                  failureMessage(l10n, failure),
                  action: FilledButton.tonal(
                    onPressed: cubit.load,
                    child: Text(l10n.retry),
                  ),
                ),
                DeparturesLoaded(:final departures) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _UpdatedAt(state),
                    Expanded(
                      child: _Board(
                        departures,
                        stop: stop,
                        onRefresh: cubit.refresh,
                      ),
                    ),
                  ],
                ),
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}

/// When the board was fetched. Stays visible while scrolling, so an
/// outdated board can never be mistaken for a live one.
class _UpdatedAt extends StatelessWidget {
  const _UpdatedAt(this.state);

  final DeparturesLoaded state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final time = formatClockTime(context, state.fetchedAt);
    final color = state.isOutdated
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    // A live region: TalkBack announces when the board turns outdated,
    // which otherwise only shows as colour and an icon.
    return Semantics(
      liveRegion: state.isOutdated,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            if (state.isOutdated) ...[
              Icon(Icons.cloud_off, size: 16, color: color),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                state.isOutdated
                    ? l10n.departuresOutdated(time)
                    : l10n.departuresUpdatedAt(time),
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board(this.departures, {required this.stop, required this.onRefresh});

  final Stop stop;

  final List<Departure> departures;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stacked = departures.isNotEmpty && _stacked(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: departures.isEmpty
          // Scrollable itself, so pull-to-refresh works on an empty board.
          ? CenteredMessage(l10n.departuresEmpty)
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: departures.length,
              itemBuilder: (context, index) => ListCard(
                child: _DepartureTile(
                  departures[index],
                  stop,
                  stacked: stacked,
                ),
              ),
            ),
    );
  }

  /// Whether line, destination and time are too tight side by side: the
  /// destination then wraps mid-word ("Schürbank-str."), so it goes below
  /// line and time instead. One answer for the whole board, so all rows
  /// look alike. Depends on the screen width (360 dp phones are common),
  /// the text size and the widest badge ("Train ICE 203").
  bool _stacked(BuildContext context) {
    final text = MediaQuery.textScalerOf(context);
    if (text.scale(10) >= 13) return true;
    final screen = MediaQuery.sizeOf(context).width;
    final badge = departures
        .map((d) => LineBadge.widthOf(context, d.line, d.mode))
        .fold<double>(0, math.max);
    final time = TextPainter(
      text: TextSpan(
        text: '88:88 +88',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      textDirection: Directionality.of(context),
      textScaler: text,
    )..layout();
    final timeWidth = math.min(screen * 0.3, time.width);
    time.dispose();
    // Card margins and padding, and the gaps between the three columns.
    final destination =
        screen - listCardMargin.horizontal - 32 - badge - timeWidth - 32;
    return destination < text.scale(120);
  }
}

class _DepartureTile extends StatelessWidget {
  const _DepartureTile(this.departure, this.stop, {required this.stacked});

  final Departure departure;
  final Stop stop;

  /// Destination below line and time, as the three are too tight in a row.
  final bool stacked;

  /// Sets or removes a reminder; null when there is nothing to offer: no
  /// reminders here (tests of a single page), cancelled, or too late.
  VoidCallback? _onTap(
    BuildContext context,
    RemindersCubit? cubit,
    bool isSet,
  ) {
    if (cubit == null || departure.isCancelled) return null;
    final leads = cubit.leadsBefore(departure.time);
    if (leads.isEmpty && !isSet) return null;
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final use24HourFormat = MediaQuery.alwaysUse24HourFormatOf(context);
    return () => unawaited(
      chooseReminder(
        context,
        cubit: cubit,
        leads: leads,
        label: (lead) => l10n.reminderBeforeDeparture(lead.inMinutes),
        set: (lead) => cubit.addForDeparture(
          departure,
          stop,
          lead: lead,
          languageCode: languageCode,
          use24HourFormat: use24HourFormat,
        ),
        remove: switch (cubit.reminderForDeparture(departure, stop)) {
          final reminder? => () => unawaited(cubit.remove(reminder)),
          null => null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final reminders = RemindersCubit.maybeWatch(context);
    final isSet = reminders?.reminderForDeparture(departure, stop) != null;
    final onTap = _onTap(context, reminders, isSet);
    final notes = [
      if (departure.isCancelled) l10n.departureCancelled,
      ...departure.notes,
    ];
    final theme = Theme.of(context);
    final destination = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          departure.destination,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: departure.isCancelled
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        if (notes.isNotEmpty)
          Text(
            notes.join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: departure.isCancelled
                  ? colors.error
                  : colors.onSurfaceVariant,
            ),
          ),
      ],
    );
    // A plain layout rather than a ListTile: ListTile fixes the height of
    // its trailing widget, which cuts off time and platform at large font
    // sizes. For TalkBack it is one item with a fixed order, whichever
    // layout is shown.
    return Semantics(
      container: true,
      button: onTap != null,
      label: [
        _departureSummary(context, departure),
        if (isSet) l10n.reminderOnDepartureSet,
      ].join(', '),
      onTap: onTap,
      onTapHint: onTap == null ? null : l10n.reminderOnDeparture,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LineBadge(departure.line, mode: departure.mode),
                              const SizedBox(width: 16),
                              Expanded(child: _TimeAndPlatform(departure)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          destination,
                        ],
                      )
                    : Row(
                        children: [
                          LineBadge(departure.line, mode: departure.mode),
                          const SizedBox(width: 16),
                          Expanded(child: destination),
                          const SizedBox(width: 16),
                          // Bounded, so the delay can move under the time instead
                          // of pushing the row off screen.
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.3,
                            ),
                            child: _TimeAndPlatform(departure),
                          ),
                        ],
                      ),
              ),
            ),
            if (isSet)
              PositionedDirectional(
                top: 4,
                end: 6,
                child: Icon(
                  Icons.notifications_active,
                  size: 16,
                  color: colors.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Train 848, Essen Hauptbahnhof, 17:25, 22 min late, Platform 3, notes":
/// what matters at a stop first, in the same order in both layouts.
String _departureSummary(BuildContext context, Departure departure) {
  final l10n = AppLocalizations.of(context);
  final delay = departure.delay?.inMinutes ?? 0;
  return [
    switch (departure.mode) {
      final mode? => '${transportModeLabel(l10n, mode)} ${departure.line}',
      null => departure.line,
    },
    departure.destination,
    formatClockTime(context, departure.plannedTime),
    if (departure.isCancelled)
      l10n.departureCancelled
    else if (delay > 0)
      l10n.departureLate(delay)
    else if (delay < 0)
      l10n.departureEarly(-delay),
    ?platformSpokenLabel(
      l10n,
      departure.platform,
      plannedPlatform: departure.plannedPlatform,
      mode: departure.mode,
    ),
    ...departure.notes,
  ].join(', ');
}

/// Planned time with the delay next to it (`17:13 +12`), and the platform
/// below. Absolute times stay correct however long the board is open.
class _TimeAndPlatform extends StatelessWidget {
  const _TimeAndPlatform(this.departure);

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final delayMinutes = departure.delay?.inMinutes ?? 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 4,
          children: [
            Text(
              formatClockTime(context, departure.plannedTime),
              style: theme.textTheme.titleMedium?.copyWith(
                decoration: departure.isCancelled
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            if (!departure.isCancelled && delayMinutes != 0) ...[
              Text(
                delayMinutes > 0 ? '+$delayMinutes' : '$delayMinutes',
                semanticsLabel: delayMinutes > 0
                    ? l10n.departureLate(delayMinutes)
                    : l10n.departureEarly(-delayMinutes),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: delayMinutes > 0 ? theme.colorScheme.error : null,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        if (departure.platform != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: PlatformChip(
              platform: departure.platform,
              plannedPlatform: departure.plannedPlatform,
              mode: departure.mode,
            ),
          ),
      ],
    );
  }
}
