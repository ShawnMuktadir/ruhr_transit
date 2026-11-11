import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/connectivity/offline_banner.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/dismiss_background.dart';
import 'package:ruhr_transit/core/widgets/show_message.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/recent_stops/presentation/recent_stops_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_state.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_tile.dart';

/// Composition root of the stop search in the Favourites tab: creates the
/// cubit, then hands over to [StopSearchBody], which tests can pump with
/// their own cubit.
class StopSearchPanel extends StatelessWidget {
  const StopSearchPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StopSearchCubit(getIt<StopRepository>()),
      child: const StopSearchBody(),
    );
  }
}

/// The search screen in pick mode: choosing a stop returns it instead of
/// opening its board. Used for the start and destination of a trip.
abstract final class StopPicker {
  /// Shows the picker titled [title]; completes with the chosen stop, or
  /// null if the user went back.
  static Future<Stop?> pick(BuildContext context, {required String title}) {
    return Navigator.of(context).push(
      MaterialPageRoute<Stop>(
        builder: (context) => BlocProvider(
          create: (_) => StopSearchCubit(
            getIt<StopRepository>(),
            // A trip can start or end at an address or a place too.
            includeAddresses: true,
          ),
          child: StopSearchView(
            title: title,
            onPicked: (stop) {
              // Only picks for From and To count as search history.
              context.read<RecentStopsCubit>().add(stop);
              Navigator.of(context).pop(stop);
            },
          ),
        ),
      ),
    );
  }
}

/// The search as a page of its own, with an app bar.
class StopSearchView extends StatelessWidget {
  const StopSearchView({this.onPicked, this.title, super.key});

  /// Set in pick mode: called with the chosen stop.
  final ValueChanged<Stop>? onPicked;

  /// App bar title; the app name if not set.
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? AppLocalizations.of(context).appTitle),
      ),
      // The picker was opened to type a stop name, so the keyboard opens.
      body: StopSearchBody(onPicked: onPicked, autofocus: onPicked != null),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}

/// The search field with the results below; before searching, the
/// favourite stops.
class StopSearchBody extends StatefulWidget {
  const StopSearchBody({this.onPicked, this.autofocus = false, super.key});

  /// Set in pick mode: called with the chosen stop instead of opening its
  /// board, and favourites cannot be removed.
  final ValueChanged<Stop>? onPicked;

  final bool autofocus;

  @override
  State<StopSearchBody> createState() => _StopSearchBodyState();
}

class _StopSearchBodyState extends State<StopSearchBody> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<StopSearchCubit>().queryChanged('');
  }

  /// Retries what failed when the phone is back online.
  @override
  Widget build(BuildContext context) => OnReconnect(
    onReconnect: () {
      final cubit = context.read<StopSearchCubit>();
      if (cubit.state is StopSearchFailed) unawaited(cubit.retry());
    },
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          // A plain text field rather than SearchBar: SearchBar's semantics
          // are a 24 dp high field inside an unlabelled tappable box,
          // which is hard to find with TalkBack.
          child: TextField(
            controller: _controller,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.search,
            onChanged: context.read<StopSearchCubit>().queryChanged,
            decoration: InputDecoration(
              hintText: l10n.stopSearchHint,
              prefixIcon: const Icon(Icons.search),
              // Rebuilds only the clear button while typing.
              suffixIcon: ValueListenableBuilder(
                valueListenable: _controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.stopSearchClear,
                        onPressed: _clear,
                      ),
              ),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: BlocBuilder<StopSearchCubit, StopSearchState>(
            builder: (context, state) => switch (state) {
              StopSearchIdle() => _StartContent(onPicked: widget.onPicked),
              StopSearchLoading() => const AppLoader(),
              StopSearchLoaded(:final stops) => _StopList(
                stops,
                onPicked: widget.onPicked,
              ),
              StopSearchEmpty(:final query) => CenteredMessage(
                l10n.stopSearchEmpty(query),
              ),
              // Saved stops still work without internet.
              StopSearchFailed(:final query, failure: NetworkFailure()) =>
                _OfflineResults(query, onPicked: widget.onPicked),
              StopSearchFailed(:final failure) => CenteredMessage.retry(
                failureMessage(l10n, failure),
                onRetry: context.read<StopSearchCubit>().retry,
              ),
            },
          ),
        ),
      ],
    );
  }
}

/// Shown before searching: the favourites, or the search hint if there are
/// none yet.
class _StartContent extends StatelessWidget {
  const _StartContent({this.onPicked});

  final ValueChanged<Stop>? onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favourites = context.watch<FavouritesCubit>().state;
    final onPicked = this.onPicked;
    // Only the From/To picker has a history; favourites are not repeated.
    final recent = onPicked == null
        ? const <Stop>[]
        : [
            for (final stop in context.watch<RecentStopsCubit>().state)
              if (!favourites.contains(stop)) stop,
          ];
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (favourites.isEmpty && recent.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.stopSearchIdle, textAlign: TextAlign.center),
          ),
        if (favourites.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l10n.favouritesTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final stop in favourites)
            if (onPicked case final onPicked?)
              StopTile(stop, isFavourite: true, onSelected: onPicked)
            else
              Dismissible(
                key: ValueKey(stop.id),
                direction: DismissDirection.endToStart,
                background: const DismissBackground(),
                onDismissed: (_) => _removeWithUndo(context, stop),
                // Swiping is not possible with TalkBack; it offers this
                // action instead (in its actions menu).
                child: Semantics(
                  customSemanticsActions: {
                    CustomSemanticsAction(label: l10n.favouriteRemove): () =>
                        _removeWithUndo(context, stop),
                  },
                  child: StopTile(stop, isFavourite: true),
                ),
              ),
        ],
        if (onPicked != null && recent.isNotEmpty)
          _RecentStops(recent, onPicked: onPicked),
      ],
    );
  }

  void _removeWithUndo(BuildContext context, Stop stop) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<FavouritesCubit>();
    final index = cubit.remove(stop);
    ScaffoldMessenger.of(context).showMessage(
      l10n.favouriteRemoved(stop.fullName),
      action: SnackBarAction(
        label: l10n.undo,
        onPressed: () => cubit.restore(stop, index),
      ),
    );
  }
}

/// The last stops picked for From or To, with a way to remove one or all.
class _RecentStops extends StatelessWidget {
  const _RecentStops(this.stops, {required this.onPicked});

  final List<Stop> stops;
  final ValueChanged<Stop> onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          // Side by side while they fit; at large text "Verlauf löschen"
          // moves below the heading instead of overflowing.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                header: true,
                container: true,
                child: Text(
                  l10n.recentStopsTitle,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton(
                onPressed: () => _clearWithUndo(context),
                child: Text(l10n.recentStopsClear),
              ),
            ],
          ),
        ),
        for (final stop in stops)
          Dismissible(
            key: ValueKey('recent ${stop.id}'),
            direction: DismissDirection.endToStart,
            background: const DismissBackground(),
            onDismissed: (_) => _removeWithUndo(context, stop),
            // Swiping is not possible with TalkBack; it offers this action.
            // Its own node, so the label and the action stay on this stop
            // instead of moving up to the whole "Recent" section.
            child: Semantics(
              container: true,
              customSemanticsActions: {
                CustomSemanticsAction(label: l10n.recentStopRemove): () =>
                    _removeWithUndo(context, stop),
              },
              child: StopTile(stop, icon: Icons.history, onSelected: onPicked),
            ),
          ),
      ],
    );
  }

  void _removeWithUndo(BuildContext context, Stop stop) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RecentStopsCubit>();
    final index = cubit.remove(stop);
    _showUndo(
      context,
      l10n.recentStopRemoved(stop.fullName),
      () => cubit.restore(stop, index),
    );
  }

  void _clearWithUndo(BuildContext context) {
    final cubit = context.read<RecentStopsCubit>();
    final previous = cubit.clear();
    _showUndo(
      context,
      AppLocalizations.of(context).recentStopsCleared,
      () => cubit.restoreAll(previous),
    );
  }

  static void _showUndo(
    BuildContext context,
    String message,
    VoidCallback undo,
  ) {
    ScaffoldMessenger.of(context).showMessage(
      message,
      action: SnackBarAction(
        label: AppLocalizations.of(context).undo,
        onPressed: undo,
      ),
    );
  }
}

class _StopList extends StatelessWidget {
  const _StopList(this.stops, {this.onPicked});

  final List<Stop> stops;
  final ValueChanged<Stop>? onPicked;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: stops.length,
      itemBuilder: (context, index) =>
          StopTile(stops[index], onSelected: onPicked),
    );
  }
}

/// Searching without internet: says so and finds [query] among the stops on
/// the phone, the favourites and, in the From/To picker, the history.
class _OfflineResults extends StatelessWidget {
  const _OfflineResults(this.query, {this.onPicked});

  final String query;
  final ValueChanged<Stop>? onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onPicked = this.onPicked;
    final wanted = query.toLowerCase();
    bool matches(Stop stop) => stop.fullName.toLowerCase().contains(wanted);

    final favourites = context.watch<FavouritesCubit>().state;
    final recent = onPicked == null
        ? const <Stop>[]
        : context.watch<RecentStopsCubit>().state;
    final savedFavourites = favourites.where(matches).toList();
    final savedRecent = [
      for (final stop in recent)
        if (matches(stop) && !favourites.contains(stop)) stop,
    ];
    if (savedFavourites.isEmpty && savedRecent.isEmpty) {
      return CenteredMessage.retry(
        l10n.stopSearchOfflineNone(query),
        icon: Icons.cloud_off_outlined,
        onRetry: context.read<StopSearchCubit>().retry,
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(l10n.stopSearchOffline)),
            ],
          ),
        ),
        for (final stop in savedFavourites)
          StopTile(stop, isFavourite: true, onSelected: onPicked),
        for (final stop in savedRecent)
          StopTile(stop, icon: Icons.history, onSelected: onPicked),
      ],
    );
  }
}
