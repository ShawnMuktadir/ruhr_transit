import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/platform/open_link.dart';
import 'package:ruhr_transit/core/widgets/show_message.dart';

/// VRR writes its notices and delay reasons in German only. Where the app
/// is in another language, these offer to open them in Google Translate
/// (the app if installed, else the browser); the app translates nothing
/// itself.
abstract final class Translate {
  /// Google Translate takes at most about 5000 characters in a link.
  static const maxLength = 5000;

  /// Whether German texts need the offer: the app is not in German.
  static bool isOffered(BuildContext context) =>
      Localizations.localeOf(context).languageCode != 'de';

  /// Google Translate with [text], from German into [languageCode].
  static Uri link(String text, {required String languageCode}) =>
      Uri.https('translate.google.com', '/', {
        'sl': 'de',
        'tl': languageCode,
        'text': text.length > maxLength ? text.substring(0, maxLength) : text,
        'op': 'translate',
      });

  /// Opens [text] in Google Translate; says so when nothing could open it.
  static Future<void> open(BuildContext context, String text) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final link = Translate.link(
      text,
      languageCode: Localizations.localeOf(context).languageCode,
    );
    if (!await openLink(link)) messenger.showMessage(l10n.translateFailed);
  }

  /// "Translate" in TalkBack's and VoiceOver's actions, for rows that read
  /// as one sentence and so hide their buttons; empty where not offered.
  static Map<CustomSemanticsAction, VoidCallback> semanticsAction(
    BuildContext context,
    String text,
  ) => {
    if (isOffered(context) && text.isNotEmpty)
      CustomSemanticsAction(
        label: AppLocalizations.of(context).translate,
      ): () =>
          unawaited(open(context, text)),
  };
}

/// A small "Translate" button for a German text from VRR; nothing where the
/// app is in German.
class TranslateButton extends StatelessWidget {
  const TranslateButton(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    if (!Translate.isOffered(context) || text.isEmpty) {
      return const SizedBox.shrink();
    }
    return TextButton.icon(
      icon: const Icon(Icons.translate, size: 18),
      label: Text(AppLocalizations.of(context).translate),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () => unawaited(Translate.open(context, text)),
    );
  }
}
