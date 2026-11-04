import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/current_location_finder.dart';
import 'package:ruhr_transit/features/trip_planner/domain/walk_to_stop.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';

/// What can be done with a stop outside the planner, provided by the home
/// shell above its tabs.
class TripActions extends InheritedWidget {
  const TripActions({
    required this.planFrom,
    required this.planTo,
    required this.walkToStop,
    required super.child,
    super.key,
  });

  /// Fills "Von" or "Nach" in the planner and opens it.
  final ValueChanged<Stop> planFrom;
  final ValueChanged<Stop> planTo;

  /// Made when needed, as it needs the location and trip services.
  final WalkToStop Function() walkToStop;

  static TripActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripActions>();

  @override
  bool updateShouldNotify(TripActions oldWidget) => false;
}

/// "Von hier", "Hierhin" and "Weg dorthin" for [stop]. Nothing where no
/// [TripActions] are provided (tests of a single page).
class StopActions extends StatefulWidget {
  const StopActions(this.stop, {super.key});

  final Stop stop;

  @override
  State<StopActions> createState() => _StopActionsState();
}

class _StopActionsState extends State<StopActions> {
  var _finding = false;

  Future<void> _walk(TripActions actions) async {
    final walk = actions.walkToStop();
    setState(() => _finding = true);
    final result = await walk.find(widget.stop);
    if (!mounted) return;
    setState(() => _finding = false);

    final l10n = AppLocalizations.of(context);
    void say(String message) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    switch (result) {
      case WalkFound(:final journey):
        unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => JourneyDetailsPage(journey: journey, runs: null),
            ),
          ),
        );
      case WalkNoLocation(:final problem):
        showHereProblem(context, problem, walk.finder);
      case WalkNotFound():
        say(l10n.stopWalkNotFound);
      case WalkFailed(:final failure):
        say(failureMessage(l10n, failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = TripActions.maybeOf(context);
    if (actions == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    // Tighter than the default, so all three fit on one row on most phones.
    final style = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      // Full width, so the buttons start at the left edge in any parent.
      child: SizedBox(
        width: double.infinity,
        // Wraps at large text instead of overflowing.
        child: Wrap(
          spacing: 6,
          children: [
            FilledButton.tonalIcon(
              style: style,
              icon: const Icon(Icons.trip_origin, size: 18),
              label: Text(l10n.stopFromHere),
              onPressed: () => actions.planFrom(widget.stop),
            ),
            FilledButton.tonalIcon(
              style: style,
              icon: const Icon(Icons.place, size: 18),
              label: Text(l10n.stopToHere),
              onPressed: () => actions.planTo(widget.stop),
            ),
            FilledButton.tonalIcon(
              style: style,
              icon: _finding
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.directions_walk, size: 18),
              label: Text(l10n.stopWalkThere),
              onPressed: _finding ? null : () => unawaited(_walk(actions)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explains in a snack bar why the user's location is not available, with
/// a way to fix it where there is one. Nothing for [HereFound].
void showHereProblem(
  BuildContext context,
  HereResult problem,
  CurrentLocationFinder finder,
) {
  final l10n = AppLocalizations.of(context);
  final (String? message, SnackBarAction? action) = switch (problem) {
    HereFound() => (null, null),
    HereDenied(permanently: true) => (
      l10n.tripHereDeniedForever,
      SnackBarAction(
        label: l10n.actionSettings,
        onPressed: () => unawaited(finder.openAppSettings()),
      ),
    ),
    HereDenied() => (l10n.tripHereDenied, null),
    HereLocationOff() => (
      l10n.tripHereOff,
      SnackBarAction(
        label: l10n.actionTurnOn,
        onPressed: () => unawaited(finder.openLocationSettings()),
      ),
    ),
    HereNoPosition() => (l10n.tripHereNoPosition, null),
    HereNothingThere() => (l10n.tripHereNothingThere, null),
    HereFailed(:final failure) => (failureMessage(l10n, failure), null),
  };
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}
