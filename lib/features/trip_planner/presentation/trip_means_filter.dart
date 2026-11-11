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

/// The name of [means] on its chip and in "Without …".
String tripMeansLabel(AppLocalizations l10n, TripMeans means) =>
    switch (means) {
      TripMeans.regionalTrain => l10n.meansRegionalTrain,
      TripMeans.suburbanTrain => l10n.modeSuburbanTrain,
      TripMeans.subway => l10n.modeSubway,
      TripMeans.tram => l10n.modeTram,
      TripMeans.bus => l10n.modeBus,
      TripMeans.ice => l10n.meansIce,
      TripMeans.intercity => l10n.meansIntercity,
      TripMeans.other => l10n.meansOther,
    };

/// One chip per means of transport, on while trips may use it. Only works
/// below an [ExcludedMeansCubit].
class TripMeansChips extends StatelessWidget {
  const TripMeansChips({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final excluded = context.watch<ExcludedMeansCubit>().state;
    final cubit = context.read<ExcludedMeansCubit>();
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final means in TripMeans.values)
          FilterChip(
            label: Text(tripMeansLabel(l10n, means)),
            selected: !excluded.contains(means),
            onSelected: (_) => cubit.toggle(means),
          ),
      ],
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

/// The chips in a sheet, from the results; a change searches again.
abstract final class TripMeansSheet {
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    // The sheet's route is outside the page's providers.
    builder: (sheet) => BlocProvider.value(
      value: context.read<ExcludedMeansCubit>(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading(AppLocalizations.of(sheet).tripMeansTitle),
              const SizedBox(height: 12),
              const TripMeansChips(),
            ],
          ),
        ),
      ),
    ),
  );
}
