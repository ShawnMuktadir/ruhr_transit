import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/platform/system_settings.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';

/// What the app does for accessibility, and the way to the phone's settings
/// for it: the app follows them but cannot change them.
class AccessibilitySection extends StatelessWidget {
  const AccessibilitySection({
    this.openSettings = openAccessibilitySettings,
    super.key,
  });

  /// Opens Android's accessibility settings; tests pass their own.
  final Future<void> Function() openSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final note = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return GroupCard(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(l10n.accessibilityIntro, style: note),
        ),
        for (final (icon, title, text) in [
          (
            Icons.format_size,
            l10n.accessibilityTextTitle,
            l10n.accessibilityText,
          ),
          (
            Icons.motion_photos_off_outlined,
            l10n.accessibilityMotionTitle,
            l10n.accessibilityMotion,
          ),
          (
            Icons.record_voice_over_outlined,
            l10n.accessibilityTalkBackTitle,
            l10n.accessibilityTalkBack,
          ),
        ])
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(text),
          ),
        ListTile(
          leading: const Icon(Icons.settings_accessibility),
          title: Text(l10n.accessibilityOpen),
          subtitle: Text(l10n.accessibilityOpenHint),
          trailing: const Icon(Icons.open_in_new),
          onTap: () => unawaited(openSettings()),
        ),
      ],
    );
  }
}
