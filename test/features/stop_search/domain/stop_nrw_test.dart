import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

Stop _at(String id, double latitude, double longitude) => Stop(
  id: id,
  name: id,
  fullName: id,
  latitude: latitude,
  longitude: longitude,
);

void main() {
  // IDs and coordinates as the service sent them.
  test('a stop ID says which state it is in', () {
    expect(_at('de:05911:5194', 51.48, 7.22).isInNrw, isTrue); // Bochum
    expect(_at('de:05315:11201', 50.94, 6.96).isInNrw, isTrue); // Köln
    expect(_at('de:11000:900003201', 52.53, 13.37).isInNrw, isFalse); // Berlin
    expect(_at('de:09262:156', 48.57, 13.45).isInNrw, isFalse); // Passau
    // Osnabrück is inside NRW's box, but its ID knows better.
    expect(_at('de:03404:71612', 52.27, 8.06).isInNrw, isFalse);
  });

  test('other IDs go by the coordinates', () {
    const bochum = 'streetID:1500000926:10:5911000:3:Kortumstr.:Bochum';
    const passau = 'poiID:100222:9262000:-1:Parkhaus Bahnhofstraße:Passau';
    expect(_at(bochum, 51.476333, 7.216526).isInNrw, isTrue);
    expect(_at(passau, 48.574483, 13.446962).isInNrw, isFalse);
    expect(_at('40012942', 52.526593, 13.36968).isInNrw, isFalse); // Berlin
  });
}
