import 'package:flutter/material.dart';
import 'package:ruhr_transit/app.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/features/favourites/domain/favourites_repository.dart';

Future<void> main() async {
  // Plugins (shared_preferences) need the binding before runApp.
  WidgetsFlutterBinding.ensureInitialized();
  configureDependencies();
  // Loaded up front, so the start screen never flashes the empty state and
  // a change can never race the load. It is a single local read.
  final favourites = await getIt<FavouritesRepository>().load();
  runApp(RuhrTransitApp(initialFavourites: favourites));
}
