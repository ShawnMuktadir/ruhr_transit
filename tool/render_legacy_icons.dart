// Renders the launcher icon PNGs for Android 7.1 and below, which cannot
// show the adaptive icon (res/mipmap-anydpi-v26/ic_launcher.xml).
//
// Draws the same shapes as res/drawable/ic_launcher_foreground.xml on a
// round background, without an image package: shapes are tested per pixel,
// supersampled for smooth edges, and written as PNG with dart:io's zlib.
//
//   dart run tool/render_legacy_icons.dart
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _resDir = 'android/app/src/main/res';

/// Launcher icon sizes in pixels per density bucket (48 dp).
const _sizes = {
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// AppTheme's seed colour, as in res/values/app_colors.xml.
const _background = (0x15, 0x65, 0xC0);

/// Samples per pixel along each axis.
const _supersampling = 4;

void main() {
  for (final MapEntry(key: density, value: size) in _sizes.entries) {
    final file = File('$_resDir/mipmap-$density/ic_launcher.png');
    file.writeAsBytesSync(_encodePng(size, _render(size)));
    stdout.writeln('Wrote ${file.path} ($size px)');
  }
}

/// RGBA pixels of the icon at [size] x [size].
Uint8List _render(int size) {
  final pixels = Uint8List(size * size * 4);
  // The adaptive icon's visible area is the middle 72 of its 108 units.
  final scale = 72 / size;
  const samples = _supersampling * _supersampling;
  for (var py = 0; py < size; py++) {
    for (var px = 0; px < size; px++) {
      var inCircle = 0;
      var inGlyph = 0;
      for (var sy = 0; sy < _supersampling; sy++) {
        for (var sx = 0; sx < _supersampling; sx++) {
          final x = 18 + (px + (sx + 0.5) / _supersampling) * scale;
          final y = 18 + (py + (sy + 0.5) / _supersampling) * scale;
          if (_inCircle(x, y, 54, 54, 36)) {
            inCircle++;
            // The vector moves the glyph down by 4 units.
            if (_inGlyph(x, y - 4)) inGlyph++;
          }
        }
      }
      final alpha = inCircle / samples;
      final white = inCircle == 0 ? 0.0 : inGlyph / inCircle;
      final i = (py * size + px) * 4;
      pixels[i] = _mix(_background.$1, white);
      pixels[i + 1] = _mix(_background.$2, white);
      pixels[i + 2] = _mix(_background.$3, white);
      pixels[i + 3] = (alpha * 255).round();
    }
  }
  return pixels;
}

int _mix(int channel, double white) =>
    (channel + (255 - channel) * white).round();

/// The tram: body minus windshield and headlights, plus pantograph and
/// wheels. Same coordinates as the vector drawable.
bool _inGlyph(double x, double y) {
  final body =
      _inRoundedRect(x, y, 36, 30, 72, 74, 4) &&
      !_inRoundedRect(x, y, 40, 36, 68, 52, 2) &&
      !_inCircle(x, y, 45, 63, 3) &&
      !_inCircle(x, y, 63, 63, 3);
  return body ||
      _inRect(x, y, 53, 23, 55, 30) ||
      _inRect(x, y, 46, 21, 62, 23.5) ||
      _inRect(x, y, 41, 74, 47, 78) ||
      _inRect(x, y, 61, 74, 67, 78);
}

bool _inRect(double x, double y, num l, num t, num r, num b) =>
    x >= l && x <= r && y >= t && y <= b;

bool _inCircle(double x, double y, num cx, num cy, num r) =>
    pow(x - cx, 2) + pow(y - cy, 2) <= r * r;

bool _inRoundedRect(double x, double y, num l, num t, num r, num b, num rad) {
  if (!_inRect(x, y, l, t, r, b)) return false;
  final cx = x.clamp(l + rad, r - rad);
  final cy = y.clamp(t + rad, b - rad);
  return _inCircle(x, y, cx, cy, rad);
}

/// A minimal PNG: 8-bit RGBA, no interlacing, filter 0 on every row.
Uint8List _encodePng(int size, Uint8List rgba) {
  final raw = BytesBuilder();
  for (var y = 0; y < size; y++) {
    raw
      ..addByte(0)
      ..add(rgba.sublist(y * size * 4, (y + 1) * size * 4));
  }
  final header = ByteData(13)
    ..setUint32(0, size)
    ..setUint32(4, size)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 6); // colour type RGBA
  return (BytesBuilder()
        ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', ZLibEncoder(level: 9).convert(raw.toBytes())))
        ..add(_chunk('IEND', const [])))
      .toBytes();
}

List<int> _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32([...typeBytes, ...data]));
  return [
    ...length.buffer.asUint8List(),
    ...typeBytes,
    ...data,
    ...crc.buffer.asUint8List(),
  ];
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >>> 8);
  }
  return crc ^ 0xFFFFFFFF;
}
