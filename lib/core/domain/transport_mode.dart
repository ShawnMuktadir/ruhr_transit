/// Kinds of transport, as far as the app shows them.
///
/// Only modes whose EFA product class was verified against real responses
/// are listed (see `efa_product.dart`); unknown classes are left out rather
/// than guessed.
enum TransportMode { train, suburbanTrain, subway, tram, bus }
