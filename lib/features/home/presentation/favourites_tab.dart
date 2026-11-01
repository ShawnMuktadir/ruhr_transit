import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_list.dart';
import 'package:ruhr_transit/features/stop_search/presentation/stop_search_page.dart';

enum FavouritesSegment { journeys, stops }

/// Saved journeys and favourite stops, one segment each. The two features
/// keep their own data; this only puts them side by side.
class FavouritesTab extends StatelessWidget {
  const FavouritesTab({
    required this.segment,
    required this.onOpenJourney,
    this.stops = const StopSearchPanel(),
    super.key,
  });

  /// Owned by the shell, which switches to stops for a widget tap.
  final ValueNotifier<FavouritesSegment> segment;

  final ValueChanged<FavouriteJourney> onOpenJourney;

  /// The stops segment; tests pass one with their own cubit.
  final Widget stops;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // From 1.3x text, "Verbindungen" and an icon no longer fit half a
    // 360 dp screen, and the word would break in the middle. The icons go
    // first; if the word still does not fit, it shrinks just enough.
    final largeText = MediaQuery.textScalerOf(context).scale(10) >= 13;
    Widget label(String text) =>
        FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navFavourites)),
      body: ValueListenableBuilder(
        valueListenable: segment,
        builder: (context, selected, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<FavouritesSegment>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: FavouritesSegment.journeys,
                      icon: largeText
                          ? null
                          : const Icon(Icons.bookmark_border),
                      label: label(l10n.favouritesJourneys),
                    ),
                    ButtonSegment(
                      value: FavouritesSegment.stops,
                      icon: largeText ? null : const Icon(Icons.star_outline),
                      label: label(l10n.favouritesStops),
                    ),
                  ],
                  selected: {selected},
                  onSelectionChanged: (value) => segment.value = value.single,
                ),
              ),
            ),
            // Both stay alive, so a search or scroll position survives
            // switching segments.
            Expanded(
              child: IndexedStack(
                index: selected.index,
                children: [
                  FavouriteJourneysList(onOpen: onOpenJourney),
                  stops,
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}
