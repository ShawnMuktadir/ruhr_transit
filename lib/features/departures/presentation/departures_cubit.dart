import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/departures/domain/departure.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';
import 'package:ruhr_transit/features/departures/domain/departure_repository.dart';
import 'package:ruhr_transit/features/departures/presentation/departures_state.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';
import 'package:ruhr_transit/features/widget_sync/domain/widget_sync.dart';

/// The departure board of one stop.
///
/// Loads only when asked to: on opening, on user refresh, and when the user
/// comes back to a board that is no longer fresh ([revisited]). The VRR
/// terms allow user-triggered queries, so there is no polling while the
/// board stays on screen; instead [stillToCome] hides what has left.
///
/// When loading fails, the board shown before, or else the one saved on the
/// device, stays visible with the failure attached.
class DeparturesCubit extends Cubit<DeparturesState> {
  DeparturesCubit(
    this._repository,
    this.stopId, {
    DateTime Function() now = DateTime.now,
    WidgetSync? widgetSync,
  }) : _now = now,
       _widgetSync = widgetSync,
       super(const DeparturesLoading());

  final DepartureRepository _repository;
  final DateTime Function() _now;

  /// The home-screen widget; none on platforms without one, and in tests
  /// that do not need it.
  final WidgetSync? _widgetSync;

  /// Global ID of the stop, e.g. `de:05911:5194`.
  final String stopId;

  /// A board older than this is loaded again when the user comes back to
  /// it (to the app, its tab, or from a page on top).
  static const maxAge = Duration(minutes: 2);

  /// How long a departure stays on the board after its time, and how old a
  /// board must be before anything is hidden: a phone clock running a
  /// little ahead must not hide live departures.
  static const leftGrace = Duration(minutes: 1);

  /// Counts fetches, so a fetch that was overtaken while reading the saved
  /// board does not overwrite the newer state.
  int _fetchCount = 0;

  /// Loads from scratch, showing a spinner. Used on opening and to retry
  /// after an error.
  Future<void> load() async {
    emit(const DeparturesLoading());
    await _fetch();
  }

  /// Reloads while keeping the current board visible. The returned future
  /// completes when the board is updated, which ends the pull-to-refresh
  /// indicator.
  Future<void> refresh() async {
    if (state is! DeparturesLoaded) return load();
    await _fetch();
  }

  /// The user is back at the board: loads it again if it is older than
  /// [maxAge]. A failed board is left to Retry and [OnReconnect].
  Future<void> revisited() async {
    if (state case DeparturesLoaded(
      :final fetchedAt,
    ) when _now().difference(fetchedAt) >= maxAge) {
      await refresh();
    }
  }

  /// [state]'s departures without those that left more than [leftGrace]
  /// ago, so a board left open (or kept in a hidden tab) does not show
  /// departures that are long gone. Uses only the clock, loads nothing.
  List<Departure> stillToCome(DeparturesLoaded state) {
    final now = _now();
    if (now.difference(state.fetchedAt) < leftGrace) return state.departures;
    return _leavingFrom(state.departures, now.subtract(leftGrace));
  }

  /// Whether this phone has the home-screen widget.
  bool get hasWidget => _widgetSync?.isAvailable ?? false;

  /// Makes [stop] the widget's stop, with the board on screen so the widget
  /// is filled right away. Returns whether the launcher can also place the
  /// widget, see [addWidget].
  Future<bool> showOnWidget(Stop stop) async {
    final widgetSync = _widgetSync;
    if (widgetSync == null) return false;
    final board = switch (state) {
      DeparturesLoaded(:final departures, :final fetchedAt) => DepartureBoard(
        departures,
        fetchedAt: fetchedAt,
      ),
      _ => null,
    };
    await widgetSync.showStop(stop, board: board);
    return widgetSync.canAddWidget();
  }

  /// Asks the launcher to place the widget; the user confirms there.
  Future<void> addWidget() async => _widgetSync?.addWidget();

  Future<void> _fetch() async {
    final fetch = ++_fetchCount;
    final result = await _repository.departuresAt(stopId);
    if (isClosed) return;

    switch (result) {
      case Ok(value: final board):
        emit(DeparturesLoaded(board.departures, fetchedAt: board.fetchedAt));
      // The repository cancels a request when a newer one starts; that one
      // will update the state.
      case Err(failure: CancelledFailure()):
        return;
      case Err(:final failure):
        final fallback = switch (state) {
          DeparturesLoaded(:final departures, :final fetchedAt) =>
            DepartureBoard(departures, fetchedAt: fetchedAt),
          _ => await _repository.lastBoard(stopId),
        };
        if (isClosed || fetch != _fetchCount) return;

        final remaining = _notYetDeparted(fallback?.departures ?? const []);
        // An empty old board would claim there are no departures; the
        // error with Retry is more honest.
        if (fallback == null || remaining.isEmpty) {
          emit(DeparturesFailed(failure));
        } else {
          emit(
            DeparturesLoaded(
              remaining,
              fetchedAt: fallback.fetchedAt,
              refreshFailure: failure,
            ),
          );
        }
    }
  }

  /// Old boards only. Fresh boards are shown as the server sent them: a
  /// device clock that runs a few minutes ahead must not hide live
  /// departures.
  List<Departure> _notYetDeparted(List<Departure> departures) =>
      _leavingFrom(departures, _now());

  /// [departures] that leave at [time] or later, by estimate.
  static List<Departure> _leavingFrom(
    List<Departure> departures,
    DateTime time,
  ) => [
    for (final departure in departures)
      if (!(departure.estimatedTime ?? departure.plannedTime).isBefore(time))
        departure,
  ];
}
