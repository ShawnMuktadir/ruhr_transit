import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/features/language/presentation/language_options.dart';
import 'package:ruhr_transit/features/language/presentation/locale_cubit.dart';
import 'package:ruhr_transit/features/onboarding/presentation/onboarding_cubit.dart';

/// First launch only: a welcome step, then the language. Two steps in one
/// page rather than two routes, so finishing simply swaps the app's home
/// and Back on the language step returns to the welcome.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  var _onLanguageStep = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_onLanguageStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _onLanguageStep = false);
      },
      child: _onLanguageStep
          ? _LanguageStep(onBack: () => setState(() => _onLanguageStep = false))
          : _WelcomeStep(
              onContinue: () => setState(() => _onLanguageStep = true),
            ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _StepScaffold(
      buttonLabel: l10n.onboardingContinue,
      onPressed: onContinue,
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.tram,
              size: 48,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.appTitle,
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.onboardingDescription,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LanguageStep extends StatelessWidget {
  const _LanguageStep({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Until a language is chosen, the app shows the device's language (or
    // German), so that one is preselected.
    final selected =
        context.watch<LocaleCubit>().state ??
        AppLanguages.forDevice(
          WidgetsBinding.instance.platformDispatcher.locales,
        );
    return _StepScaffold(
      onBack: onBack,
      buttonLabel: l10n.onboardingStart,
      onPressed: () {
        // Saves the preselected language too, so it stays the same even if
        // the device language changes later.
        context.read<LocaleCubit>().select(selected);
        context.read<OnboardingCubit>().complete();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            container: true,
            child: Text(
              l10n.onboardingLanguageTitle,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          LanguageOptions(
            selected: selected,
            // Applies at once, so the rest of the flow is already in the
            // chosen language.
            onSelected: context.read<LocaleCubit>().select,
          ),
          const SizedBox(height: 16),
          Text(l10n.onboardingLanguageHint, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// Content that scrolls at large font sizes and is centred otherwise, with
/// the primary button always visible at the bottom.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.buttonLabel,
    required this.onPressed,
    required this.child,
    this.onBack,
  });

  final String buttonLabel;
  final VoidCallback onPressed;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: onBack == null ? null : BackButton(onPressed: onBack),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(child: child),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPressed,
                  child: Text(buttonLabel, textAlign: TextAlign.center),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
