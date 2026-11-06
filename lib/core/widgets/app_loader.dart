import 'package:flutter/material.dart';

/// The app's loading indicator: the tram from the app icon fills up from the
/// bottom, then fades, over and over. It shows that something is loading, not
/// how far along it is. A full, still tram when animations are removed.
class AppLoader extends StatefulWidget {
  /// Centered in the space it gets, for a page or section that is loading.
  const AppLoader({super.key}) : _size = 56;

  /// Icon-sized, for a row or a button.
  const AppLoader.small({super.key}) : _size = 24;

  final double _size;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = _TramPainter.filled;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tram = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget._size),
        painter: _TramPainter(
          _controller,
          Theme.of(context).colorScheme.primary,
        ),
      ),
    );
    return widget._size == 24 ? tram : Center(child: tram);
  }
}

class _TramPainter extends CustomPainter {
  _TramPainter(this.progress, this.color) : super(repaint: progress);

  final Animation<double> progress;
  final Color color;

  /// Parts of the loop: filling up, then full, then fading.
  static const _fillEnd = 0.6;
  static const filled = 0.7;
  static const _fadeStart = 0.75;

  /// The tram's box in the icon's coordinates.
  static const _box = Rect.fromLTRB(24, 19.5, 84, 79.5);
  static const _top = 21.0;
  static const _bottom = 78.0;

  /// The shapes of res/drawable/ic_launcher_foreground.xml.
  static final _tram = Path()
    ..fillType = PathFillType.evenOdd
    ..addRRect(_rounded(36, 30, 72, 74, 4))
    ..addRRect(_rounded(40, 36, 68, 52, 2))
    ..addOval(Rect.fromCircle(center: const Offset(45, 63), radius: 3))
    ..addOval(Rect.fromCircle(center: const Offset(63, 63), radius: 3))
    ..addRect(const Rect.fromLTRB(53, 23.5, 55, 30))
    ..addRect(const Rect.fromLTRB(46, 21, 62, 23.5))
    ..addRect(const Rect.fromLTRB(41, 74, 47, 78))
    ..addRect(const Rect.fromLTRB(61, 74, 67, 78));

  static RRect _rounded(
    double left,
    double top,
    double right,
    double bottom,
    double radius,
  ) => RRect.fromLTRBR(left, top, right, bottom, Radius.circular(radius));

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final fill = Curves.easeInOut.transform((t / _fillEnd).clamp(0, 1));
    final fade = ((t - _fadeStart) / (1 - _fadeStart)).clamp(0.0, 1.0);

    canvas
      ..scale(size.width / _box.width)
      ..translate(-_box.left, -_box.top)
      ..drawPath(_tram, Paint()..color = color.withValues(alpha: 0.2))
      ..clipRect(
        Rect.fromLTRB(
          _box.left,
          _bottom - (_bottom - _top) * fill,
          _box.right,
          _box.bottom,
        ),
      )
      ..drawPath(_tram, Paint()..color = color.withValues(alpha: 1 - fade));
  }

  @override
  bool shouldRepaint(_TramPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
