import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:ruhr_transit/features/weather/domain/weather.dart';

/// What moves or glows in a [WeatherLook].
enum WeatherScene {
  sun,
  stars,
  sunAndClouds,
  starsAndClouds,
  clouds,
  rain,
  storm,
  snow,
  fog;

  /// The sun and fog stay still: they look right that way, and it saves
  /// the battery.
  bool get moves => this != sun && this != fog;
}

/// The colours of the planner's header for one kind of weather, chosen so
/// that text stays readable; the tests check every contrast.
final class WeatherLook {
  const WeatherLook({
    required this.scene,
    required this.top,
    required this.bottom,
    required this.foreground,
    required this.secondary,
    required this.particle,
    this.glow,
  });

  final WeatherScene scene;

  /// The sky, from the top of the screen down.
  final Color top;
  final Color bottom;

  /// Text and icons on the sky.
  final Color foreground;
  final Color secondary;

  /// Clouds, stars, drops and flakes.
  final Color particle;

  /// The sun's glow in the corner.
  final Color? glow;

  /// Whether the sky is dark, which needs light status bar icons.
  bool get isDark => top.computeLuminance() < 0.3;

  /// Icons in the app bar: pure black or white, to stand out on the sky.
  Color get icon => isDark ? Colors.white : Colors.black;

  /// The look for [sky], null when the page should stay as it normally is.
  static WeatherLook? of(WeatherSky? sky, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (sky) {
      null || WeatherSky.unknown => null,
      WeatherSky.clearDay => dark ? _clearDayDark : _clearDayLight,
      WeatherSky.clearNight => _clearNight,
      WeatherSky.partlyCloudyDay => dark ? _partlyDayDark : _partlyDayLight,
      WeatherSky.partlyCloudyNight => _partlyNight,
      WeatherSky.cloudy || WeatherSky.wind => dark ? _cloudyDark : _cloudyLight,
      WeatherSky.fog => dark ? _fogDark : _fogLight,
      WeatherSky.rain => dark ? _rainDark : _rainLight,
      WeatherSky.thunderstorm => dark ? _stormDark : _stormLight,
      WeatherSky.sleet ||
      WeatherSky.snow ||
      WeatherSky.hail => dark ? _snowDark : _snowLight,
    };
  }

  static const _ink = Color(0xFF0B2239);
  static const _inkSoft = Color(0xFF1F3850);
  static const _white = Color(0xFFFFFFFF);
  static const _whiteSoft = Color(0xFFE3EAF2);

  static const _clearDayLight = WeatherLook(
    scene: WeatherScene.sun,
    top: Color(0xFF8CC6F2),
    bottom: Color(0xFFCFE8FB),
    foreground: _ink,
    secondary: _inkSoft,
    particle: Color(0x00FFFFFF),
    glow: Color(0xD9FFF4D6),
  );
  static const _clearDayDark = WeatherLook(
    scene: WeatherScene.sun,
    top: Color(0xFF1B4770),
    bottom: Color(0xFF235276),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x00FFFFFF),
    glow: Color(0x30FFC766),
  );
  static const _clearNight = WeatherLook(
    scene: WeatherScene.stars,
    top: Color(0xFF0D1B3D),
    bottom: Color(0xFF22345F),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0xFFFFFFFF),
  );
  static const _partlyDayLight = WeatherLook(
    scene: WeatherScene.sunAndClouds,
    top: Color(0xFFA2C8E6),
    bottom: Color(0xFFD6E4EF),
    foreground: _ink,
    secondary: _inkSoft,
    particle: Color(0x80FFFFFF),
    glow: Color(0xA6FFF4D6),
  );
  static const _partlyDayDark = WeatherLook(
    scene: WeatherScene.sunAndClouds,
    top: Color(0xFF2C4A66),
    bottom: Color(0xFF34506B),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x1FFFFFFF),
    glow: Color(0x26FFC766),
  );
  static const _partlyNight = WeatherLook(
    scene: WeatherScene.starsAndClouds,
    top: Color(0xFF1C2A44),
    bottom: Color(0xFF34435E),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x1FFFFFFF),
  );
  static const _cloudyLight = WeatherLook(
    scene: WeatherScene.clouds,
    top: Color(0xFFB4BFC9),
    bottom: Color(0xFFD5DBE1),
    foreground: _ink,
    secondary: _inkSoft,
    particle: Color(0x66FFFFFF),
  );
  static const _cloudyDark = WeatherLook(
    scene: WeatherScene.clouds,
    top: Color(0xFF37424D),
    bottom: Color(0xFF46525E),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x1FFFFFFF),
  );
  static const _fogLight = WeatherLook(
    scene: WeatherScene.fog,
    top: Color(0xFFC8CDD1),
    bottom: Color(0xFFDFE2E4),
    foreground: _ink,
    secondary: _inkSoft,
    particle: Color(0x59FFFFFF),
  );
  static const _fogDark = WeatherLook(
    scene: WeatherScene.fog,
    top: Color(0xFF3D4347),
    bottom: Color(0xFF4C5357),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x1AFFFFFF),
  );
  static const _rainLight = WeatherLook(
    scene: WeatherScene.rain,
    top: Color(0xFF3F5A74),
    bottom: Color(0xFF55718B),
    foreground: _white,
    secondary: _white,
    particle: Color(0x38FFFFFF),
  );
  static const _rainDark = WeatherLook(
    scene: WeatherScene.rain,
    top: Color(0xFF24364A),
    bottom: Color(0xFF30465C),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x38FFFFFF),
  );
  static const _stormLight = WeatherLook(
    scene: WeatherScene.storm,
    top: Color(0xFF252E3C),
    bottom: Color(0xFF3C4757),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x40FFFFFF),
  );
  static const _stormDark = WeatherLook(
    scene: WeatherScene.storm,
    top: Color(0xFF171D27),
    bottom: Color(0xFF262E3B),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x40FFFFFF),
  );
  static const _snowLight = WeatherLook(
    scene: WeatherScene.snow,
    top: Color(0xFFBFD6EC),
    bottom: Color(0xFFE3EEF8),
    foreground: _ink,
    secondary: _inkSoft,
    particle: Color(0xE6FFFFFF),
  );
  static const _snowDark = WeatherLook(
    scene: WeatherScene.snow,
    top: Color(0xFF34465A),
    bottom: Color(0xFF465A70),
    foreground: _white,
    secondary: _whiteSoft,
    particle: Color(0x66FFFFFF),
  );

  /// The areas text can lie on: clouds and fog are large, the sun's glow
  /// fills a corner. Stars, drops and flakes are too thin to matter.
  List<Color> get backgrounds => [
    for (final sky in [top, bottom]) ...[
      sky,
      if (glow case final glow?) Color.alphaBlend(glow, sky),
      if (_hasLargeParticles) Color.alphaBlend(particle, sky),
    ],
  ];

  bool get _hasLargeParticles => switch (scene) {
    WeatherScene.sunAndClouds ||
    WeatherScene.starsAndClouds ||
    WeatherScene.clouds ||
    WeatherScene.fog => true,
    _ => false,
  };
}

/// Paints [look] and keeps it moving, unless Android's "remove animations"
/// is on. Stops by itself in a hidden tab, under another page and while the
/// app is in the background, as tickers do.
class WeatherBackdrop extends StatefulWidget {
  const WeatherBackdrop({required this.look, super.key});

  final WeatherLook look;

  /// The soft edge into the page below.
  static const fadeHeight = 32.0;

  @override
  State<WeatherBackdrop> createState() => _WeatherBackdropState();
}

class _WeatherBackdropState extends State<WeatherBackdrop>
    with SingleTickerProviderStateMixin {
  /// Slow movement needs no more frames than this, even on a 120 Hz screen.
  static const _frame = Duration(milliseconds: 33);

  late final Ticker _ticker = createTicker(_tick);
  final _seconds = ValueNotifier<double>(0);
  Duration _painted = Duration.zero;

  void _tick(Duration elapsed) {
    if (elapsed - _painted < _frame) return;
    _painted = elapsed;
    _seconds.value = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  void _syncTicker() {
    final animate =
        widget.look.scene.moves && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_ticker.isActive) {
      _painted = Duration.zero;
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(WeatherBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _seconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _WeatherPainter(
        look: widget.look,
        pageColor: Theme.of(context).colorScheme.surface,
        seconds: _seconds,
      ),
    ),
  );
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter({
    required this.look,
    required this.pageColor,
    required this.seconds,
  }) : super(repaint: seconds);

  final WeatherLook look;
  final Color pageColor;
  final ValueListenable<double> seconds;

  /// Fixed spots in the unit square, the same on every paint.
  static final List<_Spot> _spots = () {
    final random = math.Random(7);
    return List.generate(
      70,
      (_) => _Spot(
        random.nextDouble(),
        random.nextDouble(),
        random.nextDouble(),
        random.nextDouble(),
      ),
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final area = Offset.zero & size;
    canvas
      ..save()
      ..clipRect(area)
      ..drawRect(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [look.top, look.bottom],
          ).createShader(area),
      );

    final t = seconds.value;
    switch (look.scene) {
      case WeatherScene.sun:
        _sun(canvas, size);
      case WeatherScene.stars:
        _stars(canvas, size, t, count: 45);
      case WeatherScene.sunAndClouds:
        _sun(canvas, size);
        _clouds(canvas, size, t, count: 2);
      case WeatherScene.starsAndClouds:
        _stars(canvas, size, t, count: 20);
        _clouds(canvas, size, t, count: 2);
      case WeatherScene.clouds:
        _clouds(canvas, size, t, count: 4);
      case WeatherScene.rain:
        _drops(canvas, size, t, count: 40, secondsToFall: 1.3);
      case WeatherScene.storm:
        _drops(canvas, size, t, count: 65, secondsToFall: 0.9);
      case WeatherScene.snow:
        _flakes(canvas, size, t);
      case WeatherScene.fog:
        _fog(canvas, size);
    }

    // Into the page below.
    final fade = Rect.fromLTRB(
      0,
      size.height - WeatherBackdrop.fadeHeight,
      size.width,
      size.height,
    );
    canvas
      ..drawRect(
        fade,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [pageColor.withValues(alpha: 0), pageColor],
          ).createShader(fade),
      )
      ..restore();
  }

  void _sun(Canvas canvas, Size size) {
    final glow = look.glow;
    if (glow == null) return;
    final center = Offset(size.width * 0.86, size.height * 0.14);
    final radius = size.shortestSide * 0.8;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [glow, glow.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  void _stars(Canvas canvas, Size size, double t, {required int count}) {
    final paint = Paint();
    for (final spot in _spots.take(count)) {
      // Each at its own pace, every 4 to 8 seconds.
      final phase = t / (4 + spot.c * 4) + spot.d;
      final shine = 0.55 + 0.35 * math.sin(phase * 2 * math.pi);
      paint.color = Colors.white.withValues(alpha: shine);
      canvas.drawCircle(
        Offset(spot.a * size.width, spot.b * size.height * 0.85),
        0.7 + spot.c * 0.9,
        paint,
      );
    }
  }

  void _clouds(Canvas canvas, Size size, double t, {required int count}) {
    final paint = Paint()..color = look.particle;
    final span = size.width + 240;
    for (var i = 0; i < count; i++) {
      final spot = _spots[i];
      // Across the screen in about two minutes.
      final travel = (t / (100 + spot.c * 50) + (i + spot.a) / count) % 1;
      final x = travel * span - 120;
      final y = size.height * (0.14 + 0.62 * (i / count));
      final scale = 0.8 + spot.d * 0.6;
      canvas.drawPath(
        Path()
          ..addOval(
            Rect.fromCenter(
              center: Offset(x, y + 8 * scale),
              width: 150 * scale,
              height: 34 * scale,
            ),
          )
          ..addOval(
            Rect.fromCircle(
              center: Offset(x - 26 * scale, y),
              radius: 20 * scale,
            ),
          )
          ..addOval(
            Rect.fromCircle(
              center: Offset(x + 14 * scale, y - 6 * scale),
              radius: 27 * scale,
            ),
          ),
        paint,
      );
    }
  }

  void _drops(
    Canvas canvas,
    Size size,
    double t, {
    required int count,
    required double secondsToFall,
  }) {
    final paint = Paint()
      ..color = look.particle
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const length = 15.0;
    const slant = 3.0;
    final span = size.height + length;
    for (final spot in _spots.take(count)) {
      final fall = (t / (secondsToFall * (0.85 + spot.c * 0.3)) + spot.b) % 1;
      final y = fall * span - length;
      final x = spot.a * (size.width + 20) - fall * 12;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - slant, y + length * (0.7 + spot.d * 0.5)),
        paint,
      );
    }
  }

  void _flakes(Canvas canvas, Size size, double t) {
    final paint = Paint()..color = look.particle;
    for (final spot in _spots.take(40)) {
      final fall = (t / (9 + spot.c * 6) + spot.b) % 1;
      final sway = math.sin((t / 5 + spot.d) * 2 * math.pi) * 7;
      canvas.drawCircle(
        Offset(spot.a * size.width + sway, fall * (size.height + 8) - 4),
        1.4 + spot.d * 1.8,
        paint,
      );
    }
  }

  void _fog(Canvas canvas, Size size) {
    final paint = Paint()..color = look.particle;
    for (final (y, height) in const [(0.25, 0.3), (0.55, 0.26), (0.82, 0.3)]) {
      final band = Rect.fromLTWH(
        -size.width * 0.2,
        size.height * (y - height / 2),
        size.width * 1.4,
        size.height * height,
      );
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          look.particle.withValues(alpha: 0),
          look.particle,
          look.particle.withValues(alpha: 0),
        ],
      ).createShader(band);
      canvas.drawRect(band, paint);
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter oldDelegate) =>
      oldDelegate.look != look ||
      oldDelegate.pageColor != pageColor ||
      oldDelegate.seconds != seconds;
}

/// Four independent numbers from 0 to 1.
final class _Spot {
  const _Spot(this.a, this.b, this.c, this.d);

  final double a;
  final double b;
  final double c;
  final double d;
}
