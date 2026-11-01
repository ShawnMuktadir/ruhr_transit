import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/dismiss_background.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
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

  @override
  Widget build(BuildContext context) {
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
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
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
