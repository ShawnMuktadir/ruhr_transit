/// EFA's notice texts (`infos[].infoLinks[].content`) are sometimes plain
/// text and sometimes HTML: paragraphs, `div`s, `<b>`/`<strong>`, headings,
/// `<br>` and entities such as `&szlig;`, `&nbsp;` or `&uarr;` (all seen in
/// recorded responses). This turns either into plain text with one line per
/// block, so it can be shown as is.
String efaPlainText(String source) {
  final isHtml = RegExp('<[a-zA-Z/]').hasMatch(source);
  // In HTML, line breaks in the source are just spaces; only blocks start
  // a new line. Plain text keeps its line breaks.
  var text = isHtml ? source.replaceAll(RegExp(r'\s+'), ' ') : source;
  text = text
      // Every block ends a line.
      .replaceAll(
        RegExp(
          r'<\s*(br|/p|p|/div|div|/h[1-6]|/tr)\b[^>]*>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(RegExp(r'<\s*li\b[^>]*>', caseSensitive: false), '\n• ')
      // All other tags (bold, links, spans) only lose their markup.
      .replaceAll(RegExp('<[^>]*>'), '');
  text = _decodeEntities(text);
  final lines = text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
      .toList();
  // At most one empty line in a row, none at the start or end.
  final result = <String>[];
  for (final line in lines) {
    if (line.isEmpty && (result.isEmpty || result.last.isEmpty)) continue;
    result.add(line);
  }
  while (result.isNotEmpty && result.last.isEmpty) {
    result.removeLast();
  }
  return result.join('\n');
}

const _namedEntities = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': ' ',
  'szlig': 'ß',
  'auml': 'ä',
  'ouml': 'ö',
  'uuml': 'ü',
  'Auml': 'Ä',
  'Ouml': 'Ö',
  'Uuml': 'Ü',
  'eacute': 'é',
  'euro': '€',
  'ndash': '–',
  'mdash': '—',
  'bdquo': '„',
  'ldquo': '“',
  'rdquo': '”',
  'hellip': '…',
  'uarr': '↑',
  'darr': '↓',
  'larr': '←',
  'rarr': '→',
};

String _decodeEntities(String text) => text.replaceAllMapped(
  RegExp('&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);'),
  (match) {
    final entity = match.group(1)!;
    if (entity.startsWith('#x') || entity.startsWith('#X')) {
      final code = int.tryParse(entity.substring(2), radix: 16);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    }
    if (entity.startsWith('#')) {
      final code = int.tryParse(entity.substring(1));
      return code == null ? match.group(0)! : String.fromCharCode(code);
    }
    // Unknown names stay as they are rather than disappear.
    return _namedEntities[entity] ?? match.group(0)!;
  },
);
