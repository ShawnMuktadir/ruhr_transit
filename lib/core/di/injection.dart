import 'package:get_it/get_it.dart';

/// App-wide service locator. Only used at the composition root (here and
/// where pages create their cubits); classes get dependencies through their
/// constructors, which keeps them testable without get_it.
final GetIt getIt = GetIt.instance;

/// Registers all dependencies. Called once from `main()` before `runApp`.
///
/// Empty in Phase 0. The network client, database and repositories are
/// registered here as their phases add them.
void configureDependencies() {}
