import 'package:flutter_test/flutter_test.dart';
import 'package:ruhr_transit/core/network/efa_transport.dart';

void main() {
  group('readEfaTripStopName', () {
    Map<String, Object?> platform(String name, String short) => {
      'name': name,
      'type': 'platform',
      'parent': {
        'name': name,
        'disassembledName': short,
        'type': 'stop',
        'parent': {'name': 'Gelsenkirchen', 'type': 'locality'},
      },
    };

    test('writes out a name shortened with a town code', () {
      expect(
        readEfaTripStopName(
          platform('GE Buer Rath. Kunstmuseum', 'Buer Rathaus/Kunstmuseum'),
        ),
        'Gelsenkirchen Buer Rathaus/Kunstmuseum',
      );
    });

    test('keeps a full name', () {
      expect(
        readEfaTripStopName(platform('Gelsenkirchen Erlestr.', 'Erlestr.')),
        'Gelsenkirchen Erlestr.',
      );
    });

    test('keeps a shortened name it cannot write out', () {
      // A destination far away comes without its stop and town.
      expect(
        readEfaTripStopName(const {'name': 'S Südkreuz Bhf (Berlin)'}),
        'S Südkreuz Bhf (Berlin)',
      );
    });
  });
}
