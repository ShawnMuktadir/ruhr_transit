import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_page.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_cubit.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_state.dart';

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

class StopSearchView extends StatefulWidget {
  const StopSearchView({super.key});

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
      appBar: AppBar(title: Text(l10n.appTitle)),
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
                StopSearchIdle() => const _Favourites(),
                StopSearchLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                StopSearchLoaded(:final stops) => _StopList(stops),
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

/// Shown before searching: the favourites, or the search hint if there are
/// none yet.
class _Favourites extends StatelessWidget {
  const _Favourites();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favourites = context.watch<FavouritesCubit>().state;
    if (favourites.isEmpty) return CenteredMessage(l10n.stopSearchIdle);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            l10n.favouritesTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final stop in favourites)
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
            child: _StopTile(stop, isFavourite: true),
          ),
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
  const _StopList(this.stops);

  final List<Stop> stops;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: stops.length,
      itemBuilder: (context, index) => _StopTile(stops[index]),
    );
  }
}

class _StopTile extends StatelessWidget {
  const _StopTile(this.stop, {this.isFavourite = false});

  final Stop stop;
  final bool isFavourite;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(isFavourite ? Icons.star : Icons.place_outlined),
      title: Text(stop.name),
      subtitle: switch (stop.locality) {
        final locality? => Text(locality),
        null => null,
      },
      trailing: _ModeIcons(stop.modes),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => DeparturesPage(stop: stop)),
      ),
    );
  }
}

class _ModeIcons extends StatelessWidget {
  const _ModeIcons(this.modes);

  final Set<TransportMode> modes;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Enum order, so every row lists modes the same way.
        for (final mode in TransportMode.values)
          if (modes.contains(mode))
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: TransportModeIcon(mode, size: 20, color: color),
            ),
      ],
    );
  }
}
