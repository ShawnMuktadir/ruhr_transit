import 'dart:async';

import 'package:flutter/widgets.dart';

/// Builds with the current time and again every [every], so "in 4 min"
/// counts down while the page stays open. Only rebuilds; it loads nothing.
class NowBuilder extends StatefulWidget {
  const NowBuilder({
    required this.builder,
    this.every = const Duration(seconds: 15),
    this.now = DateTime.now,
    super.key,
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration every;
  final DateTime Function() now;

  @override
  State<NowBuilder> createState() => _NowBuilderState();
}

class _NowBuilderState extends State<NowBuilder> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.now());
}
