import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';
import 'package:ruhr_transit/core/l10n/gen/app_localizations.dart';
import 'package:ruhr_transit/core/widgets/app_loader.dart';
import 'package:ruhr_transit/core/widgets/centered_message.dart';
import 'package:ruhr_transit/features/legal/presentation/markdown_view.dart';

/// The legal texts, one Markdown file per language in `assets/legal/`.
enum LegalDocument {
  privacy,
  terms;

  /// e.g. `assets/legal/privacy_de.md`.
  String assetFor(AppLanguage language) =>
      'assets/legal/${name}_${language.code}.md';
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
    final language =
        AppLanguages.byCode(Localizations.localeOf(context).languageCode) ??
        AppLanguages.fallback;
    final asset = widget.document.assetFor(language);
    if (asset != _asset) {
      _asset = asset;
      _load();
    }
  }

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
      ),
      body: FutureBuilder<String>(
        future: _text,
        builder: (context, snapshot) => switch (snapshot) {
          AsyncSnapshot(:final data?) => MarkdownView(data),
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
