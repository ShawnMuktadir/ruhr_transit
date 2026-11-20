/// What a trip may use, as the user turns it on or off. Each covers EFA
/// product classes; the trip request leaves out the classes of the means
/// that are off, so VRR plans without them (verified live: without ICE it
/// answers with IC and RE, without trains with trams and buses).
///
/// In the order of the tiles: local rail, road, long distance, the rest.
/// What each class carries was checked live on 2026-11-20/21.
enum TripMeans {
  /// RE and RB; 0 is EFA's generic train class.
  regionalTrain({0, 13}),
  suburbanTrain({1}),

  /// U-Bahn and Stadtbahn.
  subway({2, 3}),
  tram({4}),

  /// City, regional and express buses, and rail replacement buses (SEV).
  bus({5, 6, 7, 17}),

  /// Rufbus: runs only when booked.
  onDemand({10}),

  /// ICE, and Eurostar (ex-Thalys), which EFA files with them.
  ice({16}),

  /// IC, EC and night trains (NightJet, EuroNight).
  intercity({15}),

  /// FlixTrain (FLX), the only operator seen in its class.
  flixtrain({14}),

  /// Rhine and other ferries ("Fähre").
  ferry({9}),

  /// The Wuppertal Schwebebahn and TaxiBus, which EFA puts in one class,
  /// and the classes not seen in VRR's data (cable cars, rack railways).
  other({8, 11, 12});

  const TripMeans(this.productClasses);

  final Set<int> productClasses;

  /// The product classes to leave out for [excluded], sorted.
  static List<int> excludedClasses(Set<TripMeans> excluded) =>
      [for (final means in excluded) ...means.productClasses]..sort();
}
