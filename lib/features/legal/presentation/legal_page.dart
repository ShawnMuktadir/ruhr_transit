import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/platform/open_link.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/core/widgets/show_message.dart';
import 'package:ruhr_transit/features/legal/presentation/markdown_view.dart';

/// The legal texts, one Markdown file per language in `assets/legal/`.
/// The website in `docs/` is built from the same files
/// (`tool/build_legal_site.dart`).
///
/// Only German and English exist: a legal translation needs a legal check.
/// The other app languages show the English text, with a note.
enum LegalDocument {
  privacy,
  terms;

  /// The languages the legal texts are written in.
  static const languages = {'de', 'en'};

  /// Whether the texts exist in [language]; otherwise English is shown.
  static bool isTranslated(AppLanguage language) =>
      languages.contains(language.code);

  static String _code(AppLanguage language) =>
      isTranslated(language) ? language.code : 'en';

  /// e.g. `assets/legal/privacy_de.md`.
  String assetFor(AppLanguage language) =>
      'assets/legal/${name}_${_code(language)}.md';

  /// The same text on the website (GitHub Pages), e.g. `.../privacy-de.html`.
  Uri onlineFor(AppLanguage language) => Uri.https(
    'shawnmuktadir.github.io',
    '/ruhr_transit/$name-${_code(language)}.html',
  );
}

/// A legal text in the app's current language.
class LegalPage extends StatefulWidget {
  const LegalPage(this.document, {super.key});

  final LegalDocument document;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  Future<String>? _text;
  String? _asset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reloads when the language changes while the page is open.
    final asset = widget.document.assetFor(_language(context));
    if (asset != _asset) {
      _asset = asset;
      _load();
    }
  }

  Future<void> _openOnline(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final link = widget.document.onlineFor(_language(context));
    if (!await openLink(link)) {
      messenger.showMessage(l10n.legalOpenOnlineFailed);
    }
  }

  static AppLanguage _language(BuildContext context) =>
      AppLanguages.byCode(Localizations.localeOf(context).languageCode) ??
      AppLanguages.fallback;

  void _load() {
    _text = DefaultAssetBundle.of(context).loadString(_asset!, cache: false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (widget.document) {
          LegalDocument.privacy => l10n.privacyPolicy,
          LegalDocument.terms => l10n.termsOfUse,
        }),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: l10n.legalOpenOnline,
            onPressed: () => unawaited(_openOnline(context)),
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _text,
        builder: (context, snapshot) => switch (snapshot) {
          AsyncSnapshot(:final data?) =>
            LegalDocument.isTranslated(_language(context))
                ? MarkdownView(data)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MaterialBanner(
                        leading: const Icon(Icons.translate),
                        content: Text(l10n.legalEnglishOnly),
                        actions: const [SizedBox.shrink()],
                      ),
                      Expanded(
                        child: MarkdownView(
                          data,
                          textDirection: TextDirection.ltr,
                        ),
                      ),
                    ],
                  ),
          AsyncSnapshot(hasError: true) => CenteredMessage.retry(
            l10n.legalLoadFailed,
            onRetry: () => setState(_load),
          ),
          _ => const AppLoader(),
        },
      ),
    );
  }
}
