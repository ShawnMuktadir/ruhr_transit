import 'package:flutter/material.dart';
import 'package:ruhr_transit/core/l10n/app_language.dart';

/// Every app language by its own name, one selectable row each. Used on
/// first launch and in the settings.
class LanguageOptions extends StatelessWidget {
  const LanguageOptions({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final AppLanguage selected;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<AppLanguage>(
      groupValue: selected,
      onChanged: (language) {
        if (language != null) onSelected(language);
      },
      child: Column(
        children: [
          for (final language in AppLanguages.all)
            RadioListTile<AppLanguage>(
              value: language,
              title: Text(language.nativeName),
            ),
        ],
      ),
    );
  }
}
