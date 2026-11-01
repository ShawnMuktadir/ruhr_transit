import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Bookmark toggle for the journey from [from] to [to]; filled while it is
/// saved. Disabled until both stops are chosen and different.
class FavouriteJourneyButton extends StatelessWidget {
  const FavouriteJourneyButton({
    required this.from,
    required this.to,
    super.key,
  });

  final Stop? from;
  final Stop? to;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<FavouriteJourneysCubit, FavouriteJourneysState>(
      builder: (context, state) {
        final cubit = context.read<FavouriteJourneysCubit>();
        final stops = switch ((from, to)) {
          (final from?, final to?) when from != to => (from, to),
          _ => null,
        };
        final saved = stops != null && cubit.find(stops.$1, stops.$2) != null;
        return IconButton(
          isSelected: saved,
          icon: const Icon(Icons.bookmark_border),
          selectedIcon: const Icon(Icons.bookmark),
          tooltip: saved ? l10n.journeyUnsave : l10n.journeySave,
          onPressed: stops != null && state is FavouriteJourneysLoaded
              ? () => cubit.toggle(stops.$1, stops.$2)
              : null,
        );
      },
    );
  }
}
