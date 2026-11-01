import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/dismiss_background.dart';
import 'package:ruhr_transit/features/favourite_journeys/domain/favourite_journey.dart';
import 'package:ruhr_transit/features/favourite_journeys/presentation/favourite_journeys_cubit.dart';

/// The saved journeys. Tapping one calls [onOpen], which plans it; a swipe,
/// the menu or a TalkBack action removes it, with undo.
class FavouriteJourneysList extends StatelessWidget {
  const FavouriteJourneysList({required this.onOpen, super.key});

  final ValueChanged<FavouriteJourney> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocBuilder<FavouriteJourneysCubit, FavouriteJourneysState>(
      builder: (context, state) => switch (state) {
        FavouriteJourneysLoading() => const Center(
          child: CircularProgressIndicator(),
        ),
        FavouriteJourneysFailed() => CenteredMessage(
          l10n.journeysLoadFailed,
          action: FilledButton.tonal(
            onPressed: context.read<FavouriteJourneysCubit>().retry,
            child: Text(l10n.retry),
          ),
        ),
        FavouriteJourneysLoaded(:final journeys) when journeys.isEmpty =>
          CenteredMessage(l10n.journeysEmpty, icon: Icons.bookmark_border),
        FavouriteJourneysLoaded(:final journeys) => ListView(
          children: [
            for (final journey in journeys)
              _JourneyTile(journey, onOpen: () => onOpen(journey)),
          ],
        ),
      },
    );
  }
}

enum _MenuAction { editLabel, remove }

class _JourneyTile extends StatelessWidget {
  const _JourneyTile(this.journey, {required this.onOpen});

  final FavouriteJourney journey;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = journey.label;
    return Dismissible(
      key: ValueKey('${journey.from.id}>${journey.to.id}'),
      direction: DismissDirection.endToStart,
      background: const DismissBackground(),
      onDismissed: (_) => _removeWithUndo(context),
      // Swiping is not possible with TalkBack; it offers this action in its
      // actions menu, like the menu button does for everyone.
      child: Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: l10n.journeyRemove): () =>
              _removeWithUndo(context),
        },
        child: ListTile(
          leading: const Icon(Icons.bookmark),
          title: Text(
            '${journey.from.fullName} → ${journey.to.fullName}',
            semanticsLabel: l10n.journeyRoute(
              journey.from.fullName,
              journey.to.fullName,
            ),
          ),
          subtitle: label == null ? null : Text(label),
          trailing: PopupMenuButton<_MenuAction>(
            tooltip: l10n.journeyOptions,
            onSelected: (action) => switch (action) {
              _MenuAction.editLabel => _editLabel(context),
              _MenuAction.remove => _removeWithUndo(context),
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _MenuAction.editLabel,
                child: Text(l10n.journeyEditLabel),
              ),
              PopupMenuItem(
                value: _MenuAction.remove,
                child: Text(l10n.journeyRemove),
              ),
            ],
          ),
          onTap: onOpen,
        ),
      ),
    );
  }

  void _removeWithUndo(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<FavouriteJourneysCubit>()..remove(journey);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l10n.journeyRemoved(journey.from.fullName, journey.to.fullName),
          ),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () => cubit.restore(journey),
          ),
        ),
      );
  }

  Future<void> _editLabel(BuildContext context) async {
    final cubit = context.read<FavouriteJourneysCubit>();
    final label = await showDialog<String>(
      context: context,
      builder: (_) => _LabelDialog(initial: journey.label),
    );
    if (label != null) await cubit.setLabel(journey, label);
  }
}

/// Completes with the entered label (empty to clear it), or null when
/// cancelled.
class _LabelDialog extends StatefulWidget {
  const _LabelDialog({this.initial});

  final String? initial;

  @override
  State<_LabelDialog> createState() => _LabelDialogState();
}

class _LabelDialogState extends State<_LabelDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    void save() => Navigator.of(context).pop(_controller.text);
    return AlertDialog(
      title: Text(l10n.journeyEditLabel),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => save(),
        decoration: InputDecoration(
          labelText: l10n.journeyLabel,
          hintText: l10n.journeyLabelHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        TextButton(onPressed: save, child: Text(l10n.save)),
      ],
    );
  }
}
