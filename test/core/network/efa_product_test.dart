import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/network/efa_product.dart';
import 'package:ruhr_transit/core/network/efa_transport.dart';

void main() {
  test('rail replacement is a bus, as EFA draws it', () {
    // A leg as the service sent it, Berlin to Passau.
    const sev = {
      'number': 'SEV RE50',
      'product': {'id': 6, 'class': 17, 'name': 'Ersatzverkehr', 'iconId': 3},
      'properties': {'trainType': 'SEV', 'trainName': 'Schienenersatzverkehr'},
    };
    expect(readEfaMode(sev), TransportMode.bus);
    expect(readEfaLine(sev), 'SEV RE50');
  });

  test('FlixTrain and EuroNight are trains', () {
    expect(transportModeForProductClass(14), TransportMode.train);
    expect(transportModeForProductClass(15), TransportMode.train);
  });

  test('classes not yet seen stay unknown', () {
    expect(transportModeForProductClass(0), isNull);
    expect(transportModeForProductClass(7), isNull);
  });
}
