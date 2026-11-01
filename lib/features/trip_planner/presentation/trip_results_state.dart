import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';

/// Sealed, so the page's `switch` must render every state.
sealed class TripResultsState {
  const TripResultsState();
}

final class TripResultsLoading extends TripResultsState {
  const TripResultsLoading();
}

/// The journeys found, possibly none.
final class TripResultsLoaded extends TripResultsState {
  const TripResultsLoaded(
    this.journeys, {
    this.isLoadingLater = false,
    this.laterFailure,
  });

  final List<Journey> journeys;

  /// "Later trips" is running; the list stays visible.
  final bool isLoadingLater;

  /// Set when loading later trips failed; [journeys] are unchanged.
  final Failure? laterFailure;
}

final class TripResultsFailed extends TripResultsState {
  const TripResultsFailed(this.failure);

  final Failure failure;
}
