import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/translate.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';

/// VRR's notices for a journey under "3 Hinweise", always collapsed, so
/// the trip starts with its rides; a warning only turns the heading's icon
/// red. Each notice opens its full text.
class TripNoticesSection extends StatelessWidget {
  const TripNoticesSection(this.notices, {super.key});

  /// Sorted by severity, see [Journey.notices].
  final List<TripNotice> notices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final german = Localizations.localeOf(context).languageCode == 'de';
    final warning = notices.any(
      (notice) => notice.severity == TripNoticeSeverity.warning,
    );
    return ExpansionTile(
      leading: Icon(
        warning ? Icons.warning_amber : Icons.info_outline,
        color: warning ? colors.error : colors.primary,
      ),
      title: Text(l10n.tripNotices(notices.length)),
      children: [
        for (final notice in notices) _NoticeTile(notice),
        // The texts come from VRR as they are.
        if (!german)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              l10n.tripNoticesGermanOnly,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile(this.notice);

  final TripNotice notice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final summary = notice.summary;
    final hasMore = notice.text.isNotEmpty || summary != null;
    // VRR titles every escalator notice "Rolltreppe außer Betrieb."; only
    // the text says which one, so it stands in for a missing summary.
    final subtitle = summary ?? (notice.text.isEmpty ? null : notice.text);
    final style = _SeverityStyle.of(context, notice.severity);
    final label = style.label;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        tileColor: style.background,
        iconColor: style.foreground,
        textColor: style.foreground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          style.icon ?? noticeIcon(notice.kind),
          semanticLabel: noticeKindLabel(l10n, notice.kind),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Not colour alone: each level also says what it is.
            if (label != null)
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: style.foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            Text(notice.title),
          ],
        ),
        subtitle: subtitle == null
            ? null
            : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: hasMore ? const Icon(Icons.chevron_right) : null,
        onTap: hasMore ? () => _showFullText(context) : null,
      ),
    );
  }

  Future<void> _showFullText(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        // Above the navigation bar, which would otherwise cover its end.
        useRootNavigator: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => _NoticeSheet(notice),
      );
}

/// The whole notice, scrollable, at most most of the screen high.
class _NoticeSheet extends StatelessWidget {
  const _NoticeSheet(this.notice);

  final TripNotice notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = notice.summary;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_SeverityStyle.of(context, notice.severity).label
                case final label?)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: notice.severity == TripNoticeSeverity.warning
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Semantics(
              header: true,
              container: true,
              child: Text(notice.title, style: theme.textTheme.titleLarge),
            ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Text(summary, style: theme.textTheme.titleSmall),
            ],
            if (notice.text.isNotEmpty) ...[
              const SizedBox(height: 16),
              SelectableText(notice.text, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 8),
            TranslateButton(
              [
                notice.title,
                notice.text,
              ].where((t) => t.isNotEmpty).join('\n\n'),
            ),
          ],
        ),
      ),
    );
  }
}

/// How a notice of each severity looks: a warning on the error colours
/// with a warning icon, a note as usual, background information muted.
class _SeverityStyle {
  const _SeverityStyle({
    this.background,
    this.foreground,
    this.icon,
    this.label,
  });

  factory _SeverityStyle.of(BuildContext context, TripNoticeSeverity severity) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return switch (severity) {
      TripNoticeSeverity.warning => _SeverityStyle(
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
        icon: Icons.warning_amber,
        label: l10n.noticeAffectsTrip,
      ),
      TripNoticeSeverity.note => const _SeverityStyle(),
      TripNoticeSeverity.background => _SeverityStyle(
        foreground: colors.onSurfaceVariant,
        label: l10n.noticeLongTerm,
      ),
    };
  }

  /// Null: the list's default.
  final Color? background;
  final Color? foreground;

  /// Null: the icon of the notice's type.
  final IconData? icon;

  /// Shown above the title; null for an ordinary note.
  final String? label;
}

IconData noticeIcon(TripNoticeKind kind) => switch (kind) {
  TripNoticeKind.facilities => Icons.elevator_outlined,
  TripNoticeKind.stop => Icons.place_outlined,
  TripNoticeKind.line => Icons.alt_route,
  TripNoticeKind.trip => Icons.train_outlined,
  TripNoticeKind.other => Icons.info_outline,
};

String noticeKindLabel(AppLocalizations l10n, TripNoticeKind kind) =>
    switch (kind) {
      TripNoticeKind.facilities => l10n.noticeFacilities,
      TripNoticeKind.stop => l10n.noticeStop,
      TripNoticeKind.line => l10n.noticeLine,
      TripNoticeKind.trip => l10n.noticeTrip,
      TripNoticeKind.other => l10n.noticeOther,
    };
