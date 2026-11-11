import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/connectivity/offline_banner.dart';
import 'package:ruhr_transit/core/di/injection.dart';
import 'package:ruhr_transit/core/error/failure_message.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/data_attribution.dart';
import 'package:ruhr_transit/core/widgets/optional_provider.dart';
import 'package:ruhr_transit/core/widgets/show_message.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journey_button.dart';
import 'package:ruhr_transit/features/trip_planner/domain/journey.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_means.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_query.dart';
import 'package:ruhr_transit/features/trip_planner/domain/trip_repository.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_details_page.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/journey_share.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/route_title.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_means_filter.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_cubit.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_results_state.dart';
import 'package:ruhr_transit/features/trip_planner/presentation/trip_widgets.dart';

/// Composition root of the results; [TripResultsView] is what tests pump.
class TripResultsPage extends StatelessWidget {
  const TripResultsPage({required this.query, super.key});

  final TripQuery query;

  @override
  Widget build(BuildContext context) {
    // The saved means of transport apply to every search, also from saved
    // journeys and reminders.
    final excluded = context.maybeRead<ExcludedMeansCubit>()?.state ?? {};
    return BlocProvider(
      create: (_) => TripResultsCubit(
        getIt<TripRepository>(),
        query.withExcluded(excluded),
      )..load(),
      child: TripResultsView(query: query),
    );
  }
}

class TripResultsView extends StatelessWidget {
  const TripResultsView({required this.query, super.key});

  final TripQuery query;

  /// Retries what failed when the phone is back online, and searches again
  /// when the means of transport change.
  @override
  Widget build(BuildContext context) {
    final page = OnReconnect(
      onReconnect: () {
        final cubit = context.read<TripResultsCubit>();
        if (cubit.state is TripResultsFailed) unawaited(cubit.load());
      },
      child: Builder(builder: _build),
    );
    final means = context.maybeRead<ExcludedMeansCubit>();
    if (means == null) return page;
    return BlocListener<ExcludedMeansCubit, Set<TripMeans>>(
      bloc: means,
      listener: (context, excluded) =>
          unawaited(context.read<TripResultsCubit>().changeExcluded(excluded)),
      child: page,
    );
  }

  Widget _build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<TripResultsCubit>();
    final wait = query.isOutsideNrw ? l10n.tripOutsideNrwWait : null;
    return Scaffold(
      appBar: RouteTitle.appBar(
        context,
        from: query.from.fullName,
        to: query.to.fullName,
        actions: [
          if (context.maybeRead<ExcludedMeansCubit>() != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_outlined),
              tooltip: l10n.tripMeansFilter,
              onPressed: () => TripMeansSheet.show(context),
            ),
          FavouriteJourneyButton(from: query.from, to: query.to),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
            onPressed: cubit.load,
          ),
        ],
      ),
      body: BlocConsumer<TripResultsCubit, TripResultsState>(
        listenWhen: (_, state) =>
            state is TripResultsLoaded && state.laterFailure != null,
        listener: (context, state) {
          final failure = (state as TripResultsLoaded).laterFailure!;
          ScaffoldMessenger.of(
            context,
          ).showMessage(failureMessage(l10n, failure));
        },
        builder: (context, state) => _WithMeansNote(
          cubit.query.excluded,
          child: switch (state) {
            TripResultsLoading() => AppLoader(message: wait),
            TripResultsFailed(:final failure) => CenteredMessage.retry(
              failureMessage(l10n, failure),
              onRetry: cubit.load,
            ),
            TripResultsLoaded(:final journeys) when journeys.isEmpty =>
              CenteredMessage(l10n.tripResultsEmpty),
            TripResultsLoaded(:final journeys, :final isLoadingLater) =>
              ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final journey in journeys)
                    _JourneyCard(journey, query: query),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: isLoadingLater
                          ? AppLoader(message: wait)
                          : OutlinedButton.icon(
                              icon: const Icon(Icons.expand_more),
                              label: Text(l10n.tripLater),
                              onPressed: cubit.loadLater,
                            ),
                    ),
                  ),
                ],
              ),
          },
        ),
      ),
      bottomNavigationBar: const DataAttribution(),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard(this.journey, {required this.query});

  final Journey journey;
  final TripQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final transfers = journey.transfers;
    final notices = journey.notices.length;
    final warning = journey.hasWarning;
    final noticeColor = warning
        ? theme.colorScheme.error
        : theme.colorScheme.primary;
    // One node for TalkBack: the summary sentence plus the tap and long-press
    // actions, instead of every time, badge and chevron on its own.
    return MergeSemantics(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  JourneyDetailsPage(journey: journey, query: query),
            ),
          ),
          onLongPress: () =>
              JourneyShareSheet.show(context, journey, query: query),
          child: Semantics(
            label: journeySummary(context, journey),
            onLongPressHint: l10n.tripShareHint,
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JourneyDate(journey),
                  Row(
                    children: [
                      Expanded(child: JourneyTimes(journey)),
                      const SizedBox(width: 8),
                      Text(
                        formatTripDuration(l10n, journey.duration),
                        style: theme.textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  JourneyLines(journey),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        transfers == 0
                            ? l10n.tripDirect
                            : l10n.tripTransfers(transfers),
                        style: theme.textTheme.bodySmall,
                      ),
                      PlatformChangeNote(journey),
                      if (journey.isTimetableOnly)
                        Text(
                          l10n.tripTimetableOnly,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      // Red with a warning icon only when a notice affects
                      // the ride; most are about lifts and stops.
                      if (notices > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              warning
                                  ? Icons.warning_amber
                                  : Icons.info_outline,
                              size: 16,
                              color: noticeColor,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                warning
                                    ? '${l10n.tripNotices(notices)} · '
                                          '${l10n.noticeAffectsTrip}'
                                    : l10n.tripNotices(notices),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: noticeColor,
                                  fontWeight: warning ? FontWeight.bold : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [child] with "Without …" above it while some means of transport are off.
class _WithMeansNote extends StatelessWidget {
  const _WithMeansNote(this.excluded, {required this.child});

  final Set<TripMeans> excluded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (excluded.isEmpty) return child;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TripMeansNote(excluded),
        ),
        Expanded(child: child),
      ],
    );
  }
}
