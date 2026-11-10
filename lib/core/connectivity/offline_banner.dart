import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ruhr_transit/core/connectivity/connectivity.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/optional_provider.dart';

/// Shows "Keine Internetverbindung" above every page while offline. For
/// `MaterialApp.builder`: the banner takes the status bar's space, so the
/// pages below do not add it again.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityCubit>().state;
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    // Bottom-up, so the banner is painted after the page: a page route
    // hides from TalkBack whatever was painted before it.
    return Column(
      verticalDirection: VerticalDirection.up,
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: !online,
            child: child,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: online
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  container: true,
                  liveRegion: true,
                  child: Material(
                    color: colors.errorContainer,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 20,
                              color: colors.onErrorContainer,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                l10n.offlineBanner,
                                style: TextStyle(
                                  color: colors.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Calls [onReconnect] when the phone comes back online, so a page can
/// retry what failed. Does nothing where no [ConnectivityCubit] is
/// provided (e.g. widget tests of a single page).
class OnReconnect extends StatelessWidget {
  const OnReconnect({
    required this.onReconnect,
    required this.child,
    super.key,
  });

  final VoidCallback onReconnect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.maybeRead<ConnectivityCubit>() == null) return child;
    return BlocListener<ConnectivityCubit, bool>(
      listenWhen: (wasOnline, online) => !wasOnline && online,
      listener: (_, _) => onReconnect(),
      child: child,
    );
  }
}
