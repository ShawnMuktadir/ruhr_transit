import 'package:ruhr_transit/core/storage/json_list_store.dart';
import 'package:ruhr_transit/features/favourites/data/stop_json.dart';
import 'package:ruhr_transit/features/recent_stops/domain/recent_stops_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stored like favourite stops, in the same stop format.
class RecentStopsRepositoryImpl implements RecentStopsRepository {
  RecentStopsRepositoryImpl(SharedPreferencesAsync preferences)
    : _store = JsonListStore(
        preferences,
        key: storageKey,
        fromJson: stopFromJson,
        toJson: stopToJson,
      );

  static const storageKey = 'recent_stops_v1';

  final JsonListStore<Stop> _store;

  @override
  Future<List<Stop>> load() => _store.load();

  @override
  Future<void> save(List<Stop> stops) => _store.save(stops);
}
