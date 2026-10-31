import 'package:ruhr_transit/core/error/result.dart';
import 'package:ruhr_transit/features/departures/domain/departure_board.dart';

abstract interface class DepartureRepository {
  /// The next departures from the stop with global ID [stopId], in the
  /// order the server sends them. No departures is an empty board, not an
  /// error. A successful answer is also saved for [lastBoard].
  ///
  /// Starting a new request cancels the previous one on the same instance;
  /// the cancelled call completes with a `CancelledFailure`.
  Future<Result<DepartureBoard>> departuresAt(String stopId);

  /// The last board [departuresAt] fetched for [stopId], possibly from an
  /// earlier app session, or null if none is saved. Its departures may have
  /// left already.
  Future<DepartureBoard?> lastBoard(String stopId);
}
