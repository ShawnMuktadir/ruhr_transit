/// What a trip may use, as the user turns it on or off. Each covers EFA
/// product classes; the trip request leaves out the classes of the means
/// that are off, so VRR plans without them (verified live: without ICE it
/// answers with IC and RE, without trains with trams and buses).
enum TripMeans {
  /// RE and RB; 0 is EFA's generic train class.
  regionalTrain({0, 13}),
  suburbanTrain({1}),

  /// U-Bahn and Stadtbahn.
  subway({2, 3}),
  tram({4}),

  /// City, regional and express buses, and rail replacement buses (SEV).
  bus({5, 6, 7, 17}),
  ice({16}),

  /// IC, EC and night trains (15), and Flixtrain (14).
  intercity({14, 15}),

  /// Cable cars, ferries, on-demand buses and anything else.
  other({8, 9, 10, 11, 12});

  const TripMeans(this.productClasses);

  final Set<int> productClasses;

  /// The product classes to leave out for [excluded], sorted.
  static List<int> excludedClasses(Set<TripMeans> excluded) =>
      [for (final means in excluded) ...means.productClasses]..sort();
}
