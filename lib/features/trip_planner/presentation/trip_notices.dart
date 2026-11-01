import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';

/// VRR's notices for a journey, collapsed under "3 Hinweise" so a trip
/// with many lift notices still starts with its rides. Each notice opens
/// its full text.
class TripNoticesSection extends StatelessWidget {
  const TripNoticesSection(this.notices, {super.key});

  final List<TripNotice> notices;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final german = Localizations.localeOf(context).languageCode == 'de';
    return ExpansionTile(
      leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
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
    return ListTile(
      leading: Icon(
        noticeIcon(notice.kind),
        semanticLabel: noticeKindLabel(l10n, notice.kind),
      ),
      title: Text(notice.title),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: hasMore ? const Icon(Icons.chevron_right) : null,
      onTap: hasMore ? () => _showFullText(context) : null,
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
            Semantics(
              header: true,
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
          ],
        ),
      ),
    );
  }
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
