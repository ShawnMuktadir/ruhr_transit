import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';

/// The part of the day a greeting is for, by the phone's local clock.
enum GreetingTime {
  /// 05:00 to 10:59.
  morning,

  /// 11:00 to 17:59.
  afternoon,

  /// 18:00 to 21:59.
  evening,

  /// 22:00 to 04:59.
  night;

  /// The period [time] falls into, in local time.
  static GreetingTime at(DateTime time) => switch (time.toLocal().hour) {
    >= 5 && < 11 => morning,
    >= 11 && < 18 => afternoon,
    >= 18 && < 22 => evening,
    _ => night,
  };

  /// When the period after the one at [time] begins.
  static DateTime nextChange(DateTime time) {
    final local = time.toLocal();
    final today = DateTime(local.year, local.month, local.day);
    for (final hour in const [5, 11, 18, 22]) {
      final start = today.add(Duration(hours: hour));
      if (start.isAfter(local)) return start;
    }
    return today.add(const Duration(days: 1, hours: 5));
  }
}

/// "Guten Morgen, Shawn" and "Wohin geht's heute?" at the top of the
/// planner. Switches to the next greeting when the period changes while
/// the page is open.
class GreetingHeader extends StatefulWidget {
  const GreetingHeader({
    this.displayName,
    this.now = DateTime.now,
    this.color,
    this.secondaryColor,
    super.key,
  });

  /// Over the weather background; otherwise the theme's colours.
  final Color? color;
  final Color? secondaryColor;

  /// The name from the profile; without one the greeting has no name.
  final String? displayName;

  /// The clock; tests pass a fixed time.
  final DateTime Function() now;

  @override
  State<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<GreetingHeader> {
  late GreetingTime _period;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _update();
  }

  void _update() {
    final now = widget.now();
    _period = GreetingTime.at(now);
    _timer?.cancel();
    // A second late, so the clock is surely in the new period.
    _timer = Timer(
      GreetingTime.nextChange(now).difference(now) + const Duration(seconds: 1),
      () => setState(_update),
    );
  }

  @override
  void didUpdateWidget(GreetingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.now != widget.now) _update();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final greeting = l10n.homeGreeting(_period.name);
    // Along with the background as it fades in.
    final fade = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 400);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: AnimatedDefaultTextStyle(
            duration: fade,
            style: theme.textTheme.headlineMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: widget.color ?? theme.colorScheme.onSurface,
            ),
            child: Text(switch (widget.displayName) {
              final name? => l10n.homeGreetingWithName(greeting, name),
              null => greeting,
            }),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: fade,
          style: theme.textTheme.titleMedium!.copyWith(
            color: widget.secondaryColor ?? theme.colorScheme.onSurfaceVariant,
          ),
          child: Text(l10n.homeGreetingQuestion),
        ),
      ],
    );
  }
}
