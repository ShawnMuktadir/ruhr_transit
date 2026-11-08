import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/domain/transport_mode.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/transport_mode_icon.dart';

/// A line as a badge with its transport icon and type in words, e.g.
/// [bus icon] Bus 302, so a bare number says what it is.
class LineBadge extends StatelessWidget {
  const LineBadge(this.line, {this.mode, this.minWidth = 64, super.key});

  final String line;
  final TransportMode? mode;

  /// Keeps badges in a column the same width; smaller in a row of badges.
  final double minWidth;

  /// How wide the badge for [line] and [mode] is on this screen, at this
  /// text size.
  static double widthOf(
    BuildContext context,
    String line,
    TransportMode? mode, {
    double minWidth = 64,
  }) {
    final painter = TextPainter(
      text: _label(context, line, mode),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final text = painter.width;
    painter.dispose();
    // Padding, and the icon with its gap.
    return math.max(minWidth, text + 16 + (mode == null ? 0 : 20));
  }

  static TextSpan _label(
    BuildContext context,
    String line,
    TransportMode? mode,
  ) {
    final colors = Theme.of(context).colorScheme;
    return TextSpan(
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(color: colors.onPrimaryContainer),
      children: [
        if (mode case final mode?)
          TextSpan(
            text: '${transportModeLabel(AppLocalizations.of(context), mode)} ',
          ),
        TextSpan(
          text: line,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (mode case final mode?) ...[
            // The words below say it already.
            ExcludeSemantics(
              child: TransportModeIcon(
                mode,
                size: 16,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(child: Text.rich(_label(context, line, mode))),
        ],
      ),
    );
  }
}
