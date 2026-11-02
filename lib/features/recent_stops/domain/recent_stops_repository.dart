import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// The stops last picked for From or To in the trip planner, newest first.
abstract interface class RecentStopsRepository {
  Future<List<Stop>> load();

  Future<void> save(List<Stop> stops);
}
