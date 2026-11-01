import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

/// A trip the user saved to plan again with one tap: start, destination
/// and an optional label of their own (e.g. "Work, RE1 at 7:40").
class FavouriteJourney {
  const FavouriteJourney({
    required this.from,
    required this.to,
    required this.savedAt,
    this.label,
  });

  final Stop from;
  final Stop to;

  /// Orders the list; kept on undo, so a restored journey returns to its
  /// place.
  final DateTime savedAt;

  /// Null or non-empty.
  final String? label;

  /// One journey per direction: Bochum → Dortmund and back are two.
  bool connects(Stop from, Stop to) => this.from == from && this.to == to;

  FavouriteJourney withLabel(String? label) => FavouriteJourney(
    from: from,
    to: to,
    savedAt: savedAt,
    label: label == null || label.trim().isEmpty ? null : label.trim(),
  );

  @override
  String toString() => 'FavouriteJourney(${from.id} → ${to.id})';
}
