import 'dart:math' as math;

import 'package:flutter/material.dart';

/// "Berlin, S+U Hauptbahnhof" over "→ Passau, Hauptbahnhof" in an app bar:
/// with towns, so both ends of a trip can be read. A long name wraps onto a
/// second line rather than being cut off, and the bar grows to fit.
class RouteTitle extends StatelessWidget {
  const RouteTitle({required this.from, required this.to, super.key});

  final String from;
  final String to;

  /// Lines per name; past that, the end is cut off with "…".
  static const _maxLines = 2;

  /// An app bar with this title, tall enough for it on this screen and at
  /// this text size. [actions] are counted to know the room for the title.
  static AppBar appBar(
    BuildContext context, {
    required String from,
    required String to,
    List<Widget> actions = const [],
  }) {
    final theme = Theme.of(context);
    // The back button, each action and the spacing around the title, plus
    // a little to spare: too much room only costs a line of height.
    final width =
        MediaQuery.sizeOf(context).width -
        kToolbarHeight -
        actions.length * kMinInteractiveDimension -
        2 * NavigationToolbar.kMiddleSpacing -
        8;
    double height(String text, TextStyle? style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: _maxLines,
        ellipsis: '…',
      )..layout(maxWidth: math.max(width, 1));
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final lines =
        height(from, theme.textTheme.titleMedium) +
        height('→ $to', theme.textTheme.bodyMedium);
    return AppBar(
      toolbarHeight: math.max(kToolbarHeight, lines + 16),
      title: RouteTitle(from: from, to: to),
      actions: actions,
    );
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
            maxLines: _maxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          Text(
            '→ $to',
            maxLines: _maxLines,
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
