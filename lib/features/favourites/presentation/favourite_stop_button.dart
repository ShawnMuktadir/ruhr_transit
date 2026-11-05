import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/favourites/presentation/favourites_cubit.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// The star that saves or removes [stop] as a favourite.
class FavouriteStopButton extends StatelessWidget {
  const FavouriteStopButton(this.stop, {super.key});

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
