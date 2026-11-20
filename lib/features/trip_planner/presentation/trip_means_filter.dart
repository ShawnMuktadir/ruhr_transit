import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/storage/setting_cubit.dart';
import 'package:ruhr_transit/core/widgets/heading.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_means.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which means of transport the user turned off, saved on the phone and
/// applied to every trip search. Provided above `MaterialApp`.
class ExcludedMeansCubit extends SettingCubit<Set<TripMeans>> {
  ExcludedMeansCubit(SharedPreferencesAsync preferences)
    : super(
        SettingStore(
          preferences,
          key: 'trip_means_excluded_v1',
          defaultValue: const {},
          // Names, so a reordered enum does not change what was saved.
          fromText: (text) => {
            for (final name in text.split(','))
              ...TripMeans.values.where((means) => means.name == name),
          },
          toText: (excluded) => [for (final m in excluded) m.name].join(','),
        ),
      );

  /// Turns [means] on or off. The last one that is on stays on: a trip
  /// needs something to travel with.
  Future<void> toggle(TripMeans means) async {
    final excluded = {...state};
    if (!excluded.remove(means)) {
      if (excluded.length == TripMeans.values.length - 1) return;
      excluded.add(means);
    }
    await set(excluded);
  }
}

/// The name of [means] on its tile and in "Without …".
String tripMeansLabel(AppLocalizations l10n, TripMeans means) =>
    switch (means) {
      TripMeans.regionalTrain => l10n.meansRegionalTrain,
      TripMeans.suburbanTrain => l10n.modeSuburbanTrain,
      TripMeans.subway => l10n.modeSubway,
      TripMeans.tram => l10n.modeTram,
      TripMeans.bus => l10n.modeBus,
      TripMeans.onDemand => l10n.meansOnDemand,
      TripMeans.ice => l10n.meansIce,
      TripMeans.intercity => l10n.meansIntercity,
      TripMeans.flixtrain => l10n.meansFlixtrain,
      TripMeans.ferry => l10n.meansFerry,
      TripMeans.other => l10n.meansOther,
    };

/// The icon of [means] on its tile, like the stops' mode icons.
IconData tripMeansIcon(TripMeans means) => switch (means) {
  TripMeans.regionalTrain => Icons.train,
  TripMeans.suburbanTrain => Icons.directions_railway,
  TripMeans.subway => Icons.subway,
  TripMeans.tram => Icons.tram,
  TripMeans.bus => Icons.directions_bus,
  TripMeans.onDemand => Icons.hail,
  TripMeans.ice => Icons.directions_railway_filled,
  TripMeans.intercity => Icons.train_outlined,
  TripMeans.flixtrain => Icons.directions_transit,
  TripMeans.ferry => Icons.directions_boat,
  TripMeans.other => Icons.more_horiz,
};

/// One tile per means of transport, on while trips may use it: three of
/// the same width in a row, on any phone. Fewer per row only when a word
/// of a name would not fit, e.g. at a large text size, so no word is ever
/// cut. Only works below an [ExcludedMeansCubit].
class TripMeansGrid extends StatelessWidget {
  const TripMeansGrid({super.key});

  static const _spacing = 8.0;

  /// Room for the text inside a tile: its padding on both sides.
  static const _tilePadding = 8.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final excluded = context.watch<ExcludedMeansCubit>().state;
    final cubit = context.read<ExcludedMeansCubit>();
    final style = TripMeansTile.labelStyle(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final labels = {
      for (final means in TripMeans.values) means: tripMeansLabel(l10n, means),
    };
    // The widest single word: a tile may wrap between words, not inside.
    var widestWord = 0.0;
    for (final word in labels.values.expand((l) => l.split(' '))) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      if (painter.width > widestWord) widestWord = painter.width;
      painter.dispose();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        double columnWidth(int columns) =>
            (constraints.maxWidth - (columns - 1) * _spacing) / columns;
        final columns = [3, 2].firstWhere(
          (n) => columnWidth(n) - 2 * _tilePadding >= widestWord,
          orElse: () => 1,
        );
        const means = TripMeans.values;
        return Column(
          children: [
            for (var start = 0; start < means.length; start += columns)
              Padding(
                padding: EdgeInsets.only(top: start == 0 ? 0 : _spacing),
                // Tiles in a row share the height of the tallest.
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = start; i < start + columns; i++) ...[
                        if (i > start) const SizedBox(width: _spacing),
                        Expanded(
                          child: i < means.length
                              ? TripMeansTile(
                                  icon: tripMeansIcon(means[i]),
                                  label: labels[means[i]]!,
                                  selected: !excluded.contains(means[i]),
                                  onTap: () => cubit.toggle(means[i]),
                                )
                              // Keeps the last row's tiles as wide as the
                              // others.
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A means of transport that can be turned on and off: filled while on,
/// outlined while off.
class TripMeansTile extends StatelessWidget {
  const TripMeansTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static TextStyle? labelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;
    return Semantics(
      button: true,
      toggled: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.secondaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: selected
              ? BorderSide.none
              : BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: kMinInteractiveDimension,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TripMeansGrid._tilePadding,
                vertical: 10,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 22, color: foreground),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: labelStyle(context)?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Without ICE, Bus" while some means are off; nothing otherwise, so a
/// filter is never forgotten.
class TripMeansNote extends StatelessWidget {
  const TripMeansNote(this.excluded, {super.key});

  final Set<TripMeans> excluded;

  @override
  Widget build(BuildContext context) {
    if (excluded.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final names = [
      for (final means in TripMeans.values)
        if (excluded.contains(means)) tripMeansLabel(l10n, means),
    ].join(', ');
    return Row(
      children: [
        Icon(
          Icons.filter_alt_outlined,
          size: 16,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            l10n.tripMeansWithout(names),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// The tiles in a sheet, from the results; a change searches again.
abstract final class TripMeansSheet {
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    // The sheet's route is outside the page's providers.
    builder: (sheet) => BlocProvider.value(
      value: context.read<ExcludedMeansCubit>(),
      child: SafeArea(
        // Scrolls on a short screen or at a large text size.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading(AppLocalizations.of(sheet).tripMeansTitle),
              const SizedBox(height: 12),
              const TripMeansGrid(),
            ],
          ),
        ),
      ),
    ),
  );
}
