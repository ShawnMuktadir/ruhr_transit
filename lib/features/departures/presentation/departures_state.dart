import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';

/// Sealed, so the page's `switch` must render every state.
sealed class DeparturesState {
  const DeparturesState();
}

/// First load, or a retry after an error. Not used for refreshes, which
/// keep the current board visible.
final class DeparturesLoading extends DeparturesState {
  const DeparturesLoading();
}

/// The board, possibly empty.
final class DeparturesLoaded extends DeparturesState {
  const DeparturesLoaded(this.departures, {this.refreshFailure});

  final List<Departure> departures;

  /// Set when a refresh failed. [departures] are then the previous ones:
  /// a slightly old board is more useful at a stop than an error screen.
  final Failure? refreshFailure;
}

/// Loading failed and there is no board to show.
final class DeparturesFailed extends DeparturesState {
  const DeparturesFailed(this.failure);

  final Failure failure;
}
