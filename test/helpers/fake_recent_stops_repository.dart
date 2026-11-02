import 'package:ruhr_transit/features/recent_stops/domain/recent_stops_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// In-memory history. [saved] is what the app last stored.
class FakeRecentStopsRepository implements RecentStopsRepository {
  FakeRecentStopsRepository([List<Stop> initial = const []])
    : saved = [...initial];

  List<Stop> saved;

  @override
  Future<List<Stop>> load() async => [...saved];

  @override
  Future<void> save(List<Stop> stops) async => saved = [...stops];
}
