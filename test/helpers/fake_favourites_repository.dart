import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// In-memory favourites. [saved] is what the app last stored.
class FakeFavouritesRepository implements FavouritesRepository {
  FakeFavouritesRepository([List<Stop> initial = const []])
    : saved = [...initial];

  List<Stop> saved;
  int saveCount = 0;

  @override
  Future<List<Stop>> load() async => [...saved];

  @override
  Future<void> save(List<Stop> stops) async {
    saveCount++;
    saved = [...stops];
  }
}
