import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "Berlin, S+U Hauptbahnhof" over "→ Passau, Hauptbahnhof" in an app bar:
/// with towns, on two lines, so both ends of a trip can be read.
class RouteTitle extends StatelessWidget {
  const RouteTitle({required this.from, required this.to, super.key});

  final String from;
  final String to;

  /// Tall enough for both lines at any text size.
  static double toolbarHeight(BuildContext context) {
    final text = MediaQuery.textScalerOf(context);
    return math.max(kToolbarHeight, 16 + text.scale(24) + text.scale(20));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      label: '$from → $to',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            from,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          Text(
            '→ $to',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
