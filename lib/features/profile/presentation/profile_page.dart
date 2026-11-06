import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';
import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';

/// The display name, kept on this device. Once accounts exist, the signed-in
/// user and "Log out" appear here; until then there is no fake login.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsProfile)),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) =>
            state.isLoading ? const AppLoader() : _ProfileForm(state),
      ),
    );
  }
}

class _ProfileForm extends StatefulWidget {
  const _ProfileForm(this.state);

  final ProfileState state;

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  late final _name = TextEditingController(text: widget.state.displayName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    final saved = await context.read<ProfileCubit>().saveDisplayName(
      _name.text,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(saved ? l10n.profileSaved : l10n.profileSaveFailed),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.state.auth case SignedIn(:final user)) ...[
          ListCard(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(l10n.profileSignedInAs(user.displayName)),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _name,
                  maxLength: 40,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                  decoration: InputDecoration(
                    labelText: l10n.profileNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(l10n.profileLocalOnly, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(onPressed: _save, child: Text(l10n.save)),
        if (widget.state.auth is SignedIn) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: Text(l10n.logOut),
            onPressed: context.read<ProfileCubit>().signOut,
          ),
        ],
      ],
    );
  }
}
