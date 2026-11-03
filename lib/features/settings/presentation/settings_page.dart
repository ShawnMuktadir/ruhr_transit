import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/cards.dart';
import 'package:ruhr_transit/features/language/presentation/language_options.dart';
import 'package:ruhr_transit/features/language/presentation/locale_cubit.dart';
import 'package:ruhr_transit/features/legal/presentation/legal_page.dart';
import 'package:ruhr_transit/features/profile/domain/auth_repository.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_cubit.dart';
import 'package:ruhr_transit/features/profile/presentation/profile_page.dart';
import 'package:ruhr_transit/features/settings/presentation/theme_cubit.dart';

/// Appearance, language, profile, legal texts and about.
class SettingsPage extends StatelessWidget {
  const SettingsPage({this.packageInfo = PackageInfo.fromPlatform, super.key});

  /// Reads the app version; tests pass their own.
  final Future<PackageInfo> Function() packageInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language =
        context.watch<LocaleCubit>().state ??
        AppLanguages.forDevice(
          WidgetsBinding.instance.platformDispatcher.locales,
        );
    final themeMode = context.watch<ThemeCubit>().state;
    final profile = context.watch<ProfileCubit>().state;

    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navSettings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _SectionHeader(l10n.settingsAppearance),
          GroupCard(
            children: [
              RadioGroup<ThemeMode>(
                groupValue: themeMode,
                onChanged: (mode) {
                  if (mode != null) context.read<ThemeCubit>().select(mode);
                },
                child: Column(
                  children: [
                    for (final (mode, label) in [
                      (ThemeMode.system, l10n.themeSystem),
                      (ThemeMode.light, l10n.themeLight),
                      (ThemeMode.dark, l10n.themeDark),
                    ])
                      RadioListTile<ThemeMode>(value: mode, title: Text(label)),
                  ],
                ),
              ),
            ],
          ),
          _SectionHeader(l10n.settingsLanguage),
          GroupCard(
            children: [
              LanguageOptions(
                selected: language,
                onSelected: context.read<LocaleCubit>().select,
              ),
            ],
          ),
          _SectionHeader(l10n.settingsProfile),
          GroupCard(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(l10n.settingsProfile),
                subtitle: profile.isLoading
                    ? null
                    : Text(profile.displayName ?? l10n.profileNoName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const ProfilePage()),
              ),
              // Only with a real sign-in; until accounts exist there is nothing
              // to log out of, so no button that would do nothing.
              if (profile.auth is SignedIn)
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: Text(l10n.logOut),
                  onTap: context.read<ProfileCubit>().signOut,
                ),
            ],
          ),
          _SectionHeader(l10n.settingsLegal),
          GroupCard(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: Text(l10n.privacyPolicy),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const LegalPage(LegalDocument.privacy)),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.termsOfUse),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(const LegalPage(LegalDocument.terms)),
              ),
            ],
          ),
          _SectionHeader(l10n.settingsAbout),
          GroupCard(children: [_About(packageInfo: packageInfo)]),
        ],
      ),
    );
  }
}

class _About extends StatefulWidget {
  const _About({required this.packageInfo});

  final Future<PackageInfo> Function() packageInfo;

  @override
  State<_About> createState() => _AboutState();
}

class _AboutState extends State<_About> {
  late final Future<PackageInfo> _info = widget.packageInfo();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder(
      future: _info,
      builder: (context, snapshot) {
        final version = switch (snapshot) {
          AsyncSnapshot(:final data?) =>
            '${data.version} (${data.buildNumber})',
          _ => null,
        };
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(switch (snapshot) {
                AsyncSnapshot(hasError: true) => l10n.aboutVersionUnavailable,
                _ when version != null => l10n.aboutVersion(version),
                // Reading the version takes a moment; a blank line rather
                // than a spinner for so short a wait.
                _ => '',
              }),
              subtitle: Text(l10n.dataAttribution),
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(l10n.aboutLicenses),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l10n.appTitle,
                applicationVersion: version,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}
