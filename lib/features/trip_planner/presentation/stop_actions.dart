import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/trip_planner/domain/current_location_finder.dart';
import 'package:ruhr_transit/features/trip_planner/domain/walk_to_stop.dart';

/// What a stop can do outside the planner, provided by the home shell above
/// its tabs.
class TripActions extends InheritedWidget {
  const TripActions({
    required this.planFrom,
    required this.walkToStop,
    required super.child,
    super.key,
  });

  /// Fills "Von" in the planner, opens it and asks for the destination.
  final ValueChanged<Stop> planFrom;

  /// Made when needed, as it needs the location and trip services.
  final WalkToStop Function() walkToStop;

  static TripActions? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripActions>();

  @override
  bool updateShouldNotify(TripActions oldWidget) => false;
}

/// "Verbindung von hier": the one thing to do with a stop on the way to a
/// trip. Nothing where no [TripActions] are provided (tests of a single
/// page).
class PlanFromStopButton extends StatelessWidget {
  const PlanFromStopButton(this.stop, {super.key});

  final Stop stop;

  @override
  Widget build(BuildContext context) {
    final actions = TripActions.maybeOf(context);
    if (actions == null) return const SizedBox.shrink();
    return FilledButton.icon(
      icon: const Icon(Icons.directions, size: 18),
      label: Text(AppLocalizations.of(context).stopPlanFromHere),
      onPressed: () => actions.planFrom(stop),
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
