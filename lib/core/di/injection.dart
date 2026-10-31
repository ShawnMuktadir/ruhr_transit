import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:ruhr_transit/core/network/dio_factory.dart';
import 'package:ruhr_transit/features/departures/data/departure_repository_impl.dart';
import 'package:ruhr_transit/features/departures/data/efa_departure_remote_source.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/favourites/data/favourites_repository_impl.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';
import 'package:ruhr_transit/features/stop_search/data/efa_stop_remote_source.dart';
import 'package:ruhr_transit/features/stop_search/data/stop_repository_impl.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide service locator. Only used at the composition root (here and
/// where pages create their cubits); classes get dependencies through their
/// constructors, which keeps them testable without get_it.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies. Called once from `main()` before `runApp`.
void configureDependencies() {
  getIt
    // One HTTP client for the whole app, so connections are reused.
    ..registerLazySingleton<Dio>(createEfaDio)
    ..registerLazySingleton(() => EfaStopRemoteSource(getIt()))
    // A factory, because the repository tracks its own running search:
    // two pages must not cancel each other's requests.
    ..registerFactory<StopRepository>(() => StopRepositoryImpl(getIt()))
    ..registerLazySingleton(() => EfaDepartureRemoteSource(getIt()))
    // A factory for the same reason: each departure board cancels only its
    // own refreshes.
    ..registerFactory<DepartureRepository>(
      () => DepartureRepositoryImpl(getIt()),
    )
    ..registerLazySingleton(SharedPreferencesAsync.new)
    ..registerLazySingleton<FavouritesRepository>(
      () => FavouritesRepositoryImpl(getIt()),
    );
}
