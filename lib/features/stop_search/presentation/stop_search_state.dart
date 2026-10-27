import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// Sealed, so the page's `switch` must render every state.
sealed class StopSearchState {
  const StopSearchState();
}

/// Nothing searched yet, or the query is too short.
final class StopSearchIdle extends StopSearchState {
  const StopSearchIdle();
}

final class StopSearchLoading extends StopSearchState {
  const StopSearchLoading(this.query);

  final String query;
}

final class StopSearchLoaded extends StopSearchState {
  const StopSearchLoaded(this.query, this.stops);

  final String query;
  final List<Stop> stops;
}

/// The search worked but found no stop.
final class StopSearchEmpty extends StopSearchState {
  const StopSearchEmpty(this.query);

  final String query;
}

final class StopSearchFailed extends StopSearchState {
  const StopSearchFailed(this.query, this.failure);

  final String query;
  final Failure failure;
}
