import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_placeholder_page.dart';
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
                StopSearchIdle() => _Message(l10n.stopSearchIdle),
                StopSearchLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
                StopSearchLoaded(:final stops) => _StopList(stops),
                StopSearchEmpty(:final query) => _Message(
                  l10n.stopSearchEmpty(query),
                ),
                StopSearchFailed(:final failure) => _Message(
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

class _StopList extends StatelessWidget {
  const _StopList(this.stops);

  final List<Stop> stops;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        return ListTile(
          leading: const Icon(Icons.place_outlined),
          title: Text(stop.name),
          subtitle: switch (stop.locality) {
            final locality? => Text(locality),
            null => null,
          },
          trailing: _ModeIcons(stop.modes),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DeparturesPlaceholderPage(stop: stop),
            ),
          ),
        );
      },
    );
  }
}

class _ModeIcons extends StatelessWidget {
  const _ModeIcons(this.modes);

  final Set<TransportMode> modes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Enum order, so every row lists modes the same way.
        for (final mode in TransportMode.values)
          if (modes.contains(mode))
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                switch (mode) {
                  TransportMode.train => Icons.train,
                  TransportMode.suburbanTrain => Icons.directions_railway,
                  TransportMode.subway => Icons.subway,
                  TransportMode.tram => Icons.tram,
                  TransportMode.bus => Icons.directions_bus,
                },
                size: 20,
                color: color,
                semanticLabel: switch (mode) {
                  TransportMode.train => l10n.modeTrain,
                  TransportMode.suburbanTrain => l10n.modeSuburbanTrain,
                  TransportMode.subway => l10n.modeSubway,
                  TransportMode.tram => l10n.modeTram,
                  TransportMode.bus => l10n.modeBus,
                },
              ),
            ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            if (action case final action?) ...[
              const SizedBox(height: 16),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
