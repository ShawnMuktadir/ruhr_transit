import 'package:ruhr_transit/core/error/failure.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';

/// The message shown to the user for a [Failure].
String failureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    // Cubits drop cancelled results; the network text is only a fallback.
    NetworkFailure() || CancelledFailure() => l10n.errorNetwork,
    TimeoutFailure() => l10n.errorTimeout,
    ServerFailure() => l10n.errorServer,
    ParseFailure() => l10n.errorParse,
  };
}
