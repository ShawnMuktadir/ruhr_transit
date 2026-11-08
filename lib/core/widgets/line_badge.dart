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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(color: colors.onPrimaryContainer);
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
          Text.rich(
            TextSpan(
              children: [
                if (mode case final mode?)
                  TextSpan(
                    text:
                        '${transportModeLabel(AppLocalizations.of(context), mode)} ',
                  ),
                TextSpan(
                  text: line,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            style: style,
          ),
        ],
      ),
    );
  }
}
