import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_cubit.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_state.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<DeparturesCubit>();
    return Scaffold(
      appBar: AppBar(
        title: Text(stop.fullName),
        actions: [
          _FavouriteButton(stop),
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
      body: BlocConsumer<DeparturesCubit, DeparturesState>(
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
          DeparturesLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
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
              Expanded(child: _Board(departures, onRefresh: cubit.refresh)),
            ],
          ),
        },
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
    final time = _formatTime(context, state.fetchedAt);
    final color = state.isOutdated
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
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
    );
  }
}

class _Board extends StatelessWidget {
  const _Board(this.departures, {required this.onRefresh});

  final List<Departure> departures;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: departures.isEmpty
          // Scrollable, so pull-to-refresh also works on an empty
          // board.
          ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: CenteredMessage(l10n.departuresEmpty),
                ),
              ),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: departures.length,
              itemBuilder: (context, index) =>
                  _DepartureTile(departures[index]),
              separatorBuilder: (_, _) => const Divider(height: 1),
            ),
    );
  }
}

class _FavouriteButton extends StatelessWidget {
  const _FavouriteButton(this.stop);

  final Stop stop;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isFavourite = context.select<FavouritesCubit, bool>(
      (cubit) => cubit.isFavourite(stop),
    );
    return IconButton(
      isSelected: isFavourite,
      icon: const Icon(Icons.star_border),
      selectedIcon: const Icon(Icons.star),
      tooltip: isFavourite ? l10n.favouriteRemove : l10n.favouriteAdd,
      onPressed: () => context.read<FavouritesCubit>().toggle(stop),
    );
  }
}

class _DepartureTile extends StatelessWidget {
  const _DepartureTile(this.departure);

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final notes = [
      if (departure.isCancelled) l10n.departureCancelled,
      ...departure.notes,
    ];
    return ListTile(
      leading: _LineBadge(departure),
      title: Text(
        departure.destination,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: departure.isCancelled
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: notes.isEmpty
          ? null
          : Text(
              notes.join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: departure.isCancelled
                  ? TextStyle(color: colors.error)
                  : null,
            ),
      trailing: _TimeAndPlatform(departure),
    );
  }
}

class _LineBadge extends StatelessWidget {
  const _LineBadge(this.departure);

  final Departure departure;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (departure.mode case final mode?) ...[
            TransportModeIcon(mode, size: 16, color: colors.onPrimaryContainer),
            const SizedBox(width: 4),
          ],
          Text(
            departure.line,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
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
    final platform = departure.platform;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatTime(context, departure.plannedTime),
              style: theme.textTheme.titleMedium?.copyWith(
                decoration: departure.isCancelled
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            if (!departure.isCancelled && delayMinutes != 0) ...[
              const SizedBox(width: 4),
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
        if (platform != null)
          Text(
            platform,
            semanticsLabel: departure.platformChanged
                ? l10n.departurePlatformChanged(platform)
                : l10n.departurePlatform(platform),
            style: departure.platformChanged
                ? theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.bodySmall,
          ),
      ],
    );
  }
}

/// [time] is UTC; shown in the device's time zone and 12/24-hour setting.
String _formatTime(BuildContext context, DateTime time) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(time.toLocal()),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
