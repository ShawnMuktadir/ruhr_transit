import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/features/favourites/data/stop_json.dart';
import 'package:ruhr_transit/features/stop_search/domain/stop.dart';

void main() {
  const address = Stop(
    id: 'streetID:1500000926:10:5911000',
    name: 'Kortumstr. 10',
    fullName: 'Bochum, Kortumstr. 10',
    latitude: 51.476333,
    longitude: 7.216526,
    locality: 'Bochum',
    kind: LocationKind.address,
  );

  test('keeps the kind of an address or place', () {
    final read = stopFromJson(stopToJson(address));

    expect(read, address);
    expect(read.kind, LocationKind.address);
    expect(stopToJson(address)['kind'], 'address');
  });

  test('data saved before addresses existed is a stop', () {
    final json = stopToJson(address)..remove('kind');

    expect(stopFromJson(json).kind, LocationKind.stop);
  });

  test('an unknown kind is read as a stop', () {
    final json = stopToJson(address)..['kind'] = 'mountain';

    expect(stopFromJson(json).kind, LocationKind.stop);
  });
}
