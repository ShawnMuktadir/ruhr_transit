import 'package:ruhr_transit/features/departures/domain/departure.dart';

/// The departures of one stop as fetched at [fetchedAt].
class DepartureBoard {
  const DepartureBoard(this.departures, {required this.fetchedAt});

  final List<Departure> departures;

  /// When the server answered, in UTC. Shown as "last updated", and tells
  /// how old a saved board is.
  final DateTime fetchedAt;
}
