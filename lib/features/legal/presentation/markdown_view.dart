import 'package:flutter/material.dart';

/// The few Markdown elements the legal texts use. Written here instead of
/// adding a package: flutter_markdown is discontinued, and this is all the
/// app needs.
sealed class MarkdownBlock {
  const MarkdownBlock(this.text);

  /// Inline text, possibly with **bold** parts.
  final String text;
}

/// `#` to `###`.
final class MarkdownHeading extends MarkdownBlock {
  const MarkdownHeading(this.level, super.text);

  final int level;
}

final class MarkdownParagraph extends MarkdownBlock {
  const MarkdownParagraph(super.text);
}

/// One `- ` item.
final class MarkdownBullet extends MarkdownBlock {
  const MarkdownBullet(super.text);
}

/// `> ` lines, shown highlighted (used for the draft notice).
final class MarkdownCallout extends MarkdownBlock {
  const MarkdownCallout(super.text);
}

final _heading = RegExp(r'^(#{1,3})\s+(.*)$');

/// Splits [source] into blocks. Consecutive lines of a paragraph, bullet or
/// callout are joined; a blank line ends a block.
List<MarkdownBlock> parseMarkdown(String source) {
  final blocks = <MarkdownBlock>[];
  MarkdownBlock Function(String)? open;
  final buffer = <String>[];

  void flush() {
    if (open != null && buffer.isNotEmpty) blocks.add(open!(buffer.join(' ')));
    open = null;
    buffer.clear();
  }

  for (final raw in source.split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) {
      flush();
    } else if (_heading.firstMatch(trimmed) case final match?) {
      flush();
      blocks.add(MarkdownHeading(match.group(1)!.length, match.group(2)!));
    } else if (trimmed.startsWith('- ')) {
      flush();
      open = MarkdownBullet.new;
      buffer.add(trimmed.substring(2));
    } else if (trimmed.startsWith('>')) {
      if (open != MarkdownCallout.new) flush();
      open = MarkdownCallout.new;
      buffer.add(trimmed.substring(1).trimLeft());
    } else {
      // Continues a bullet or callout; otherwise starts a paragraph.
      open ??= MarkdownParagraph.new;
      buffer.add(trimmed);
    }
  }
  flush();
  return blocks;
}

/// [text] with `**bold**` parts in bold.
TextSpan inlineSpans(String text, TextStyle? style) {
  final parts = text.split('**');
  return TextSpan(
    style: style,
    children: [
      for (var i = 0; i < parts.length; i++)
        if (parts[i].isNotEmpty)
          TextSpan(
            text: parts[i],
            // Odd parts are between two markers.
            style: i.isOdd
                ? const TextStyle(fontWeight: FontWeight.bold)
                : null,
          ),
    ],
  );
}

/// Renders [source] as a scrollable page.
class MarkdownView extends StatelessWidget {
  const MarkdownView(this.source, {super.key});

  final String source;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final blocks = parseMarkdown(source);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final block in blocks)
          switch (block) {
            MarkdownHeading(:final level, text: final value) => Padding(
              padding: EdgeInsets.only(top: level == 1 ? 8 : 20, bottom: 8),
              child: Semantics(
                header: true,
                child: Text.rich(
                  inlineSpans(value, switch (level) {
                    1 => text.headlineSmall,
                    2 => text.titleLarge,
                    _ => text.titleMedium,
                  }),
                ),
              ),
            ),
            MarkdownParagraph(text: final value) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text.rich(inlineSpans(value, text.bodyLarge)),
            ),
            MarkdownBullet(text: final value) => Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: Text('•  ', style: text.bodyLarge)),
                  Expanded(
                    child: Text.rich(inlineSpans(value, text.bodyLarge)),
                  ),
                ],
              ),
            ),
            MarkdownCallout(text: final value) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text.rich(
                inlineSpans(
                  value,
                  text.bodyMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          },
      ],
    );
  }
}
