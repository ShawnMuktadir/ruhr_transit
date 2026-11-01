import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/nearby_stops/presentation/nearby_stops_page.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_state.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_tile.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_form_page.dart';

/// Composition root of the search screen: creates the cubit, then hands
/// over to [StopSearchView], which tests can pump with their own cubit.
class StopSearchPage extends StatelessWidget {
  const StopSearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StopSearchCubit(getIt<StopRepository>()),
      child: const StopSearchView(),
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
          create: (_) => StopSearchCubit(getIt<StopRepository>()),
          child: StopSearchView(
            title: title,
            onPicked: (stop) => Navigator.of(context).pop(stop),
          ),
        ),
      ),
    );
  }
}

class StopSearchView extends StatefulWidget {
  const StopSearchView({this.onPicked, this.title, super.key});

  /// Set in pick mode: called with the chosen stop, and the start content
  /// shows only favourites.
  final ValueChanged<Stop>? onPicked;

  /// App bar title; the app name if not set.
  final String? title;

  @override
  State<StopSearchView> createState() => _StopSearchViewState();
}

class _StopSearchViewState extends State<StopSearchView> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? l10n.appTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchBar(
              controller: _controller,
              autoFocus: true,
              hintText: l10n.stopSearchHint,
              leading: const Icon(Icons.search),
              textInputAction: TextInputAction.search,
              onChanged: context.read<StopSearchCubit>().queryChanged,
              trailing: [
                // Rebuilds only the clear button while typing.
                ValueListenableBuilder(
                  valueListenable: _controller,
                  builder: (context, value, _) => value.text.isEmpty
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: l10n.stopSearchClear,
                          onPressed: _clear,
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: BlocBuilder<StopSearchCubit, StopSearchState>(
              builder: (context, state) => switch (state) {
                StopSearchIdle() => _StartContent(onPicked: widget.onPicked),
                StopSearchLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                StopSearchLoaded(:final stops) => _StopList(
                  stops,
                  onPicked: widget.onPicked,
                ),
                StopSearchEmpty(:final query) => CenteredMessage(
                  l10n.stopSearchEmpty(query),
                ),
                StopSearchFailed(:final failure) => CenteredMessage(
                  failureMessage(l10n, failure),
                  action: FilledButton.tonal(
                    onPressed: context.read<StopSearchCubit>().retry,
                    child: Text(l10n.retry),
                  ),
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

/// Shown before searching: nearby stops and the trip planner, then the
/// favourites, or the search hint if there are none yet. In pick mode only
/// the favourites.
class _StartContent extends StatelessWidget {
  const _StartContent({this.onPicked});

  final ValueChanged<Stop>? onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favourites = context.watch<FavouritesCubit>().state;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (onPicked == null) ...[
          ListTile(
            leading: const Icon(Icons.near_me_outlined),
            title: Text(l10n.nearbyTitle),
            trailing: const Icon(Icons.chevron_right),
            // Location is only requested from here, never at app start.
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NearbyStopsPage()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.alt_route),
            title: Text(l10n.tripTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const TripFormPage()),
            ),
          ),
          const Divider(height: 1),
        ],
        if (favourites.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.stopSearchIdle, textAlign: TextAlign.center),
          )
        else ...[
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
                background: ColoredBox(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 24),
                      child: Icon(
                        Icons.delete_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ),
                onDismissed: (_) => _removeWithUndo(context, stop),
                child: StopTile(stop, isFavourite: true),
              ),
        ],
      ],
    );
  }

  void _removeWithUndo(BuildContext context, Stop stop) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<FavouritesCubit>();
    final index = cubit.remove(stop);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.favouriteRemoved(stop.fullName)),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => cubit.restore(stop, index),
          ),
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
