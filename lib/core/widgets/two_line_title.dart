import 'dart:math' as math;

import 'package:flutter/material.dart';

/// An app bar title with a smaller line below, e.g. a stop over its town.
/// A long name wraps onto a second line rather than being cut off, and the
/// bar grows to fit (see [appBar]).
class TwoLineTitle extends StatelessWidget {
  const TwoLineTitle({
    required this.title,
    this.subtitle,
    this.semanticsLabel,
    super.key,
  });

  final String title;
  final String? subtitle;

  /// Read by screen readers instead of the two lines.
  final String? semanticsLabel;

  /// Lines per text; past that, the end is cut off with "…".
  static const _maxLines = 2;

  /// An app bar with this title, tall enough for it on this screen and at
  /// this text size. [actions] are counted to know the room for the title.
  static AppBar appBar(
    BuildContext context, {
    required String title,
    String? subtitle,
    String? semanticsLabel,
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
    double height(String? text, TextStyle? style) {
      if (text == null) return 0;
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
        height(title, theme.textTheme.titleMedium) +
        height(subtitle, theme.textTheme.bodyMedium);
    return AppBar(
      toolbarHeight: math.max(kToolbarHeight, lines + 16),
      title: TwoLineTitle(
        title: title,
        subtitle: subtitle,
        semanticsLabel: semanticsLabel,
      ),
      actions: actions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Semantics(
      header: true,
      container: true,
      label: semanticsLabel ?? [title, ?subtitle].join(', '),
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: _maxLines,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          if (subtitle != null)
            Text(
              subtitle,
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
