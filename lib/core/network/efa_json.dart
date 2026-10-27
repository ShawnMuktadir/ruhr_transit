import 'dart:convert';

/// Decodes an EFA rapidJSON body into its top-level object.
///
/// Throws a [FormatException] if the body is missing, not JSON, or not a
/// JSON object.
Map<String, Object?> decodeEfaJson(String? body) {
  if (body == null || body.isEmpty) {
    throw const FormatException('Empty response body');
  }
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Response is not a JSON object');
  }
  return decoded;
}

/// One entry of the `systemMessages` array.
///
/// EFA sends HTTP 200 for most errors and reports them here. Not every
/// `type: "error"` entry is a real error: a successful stop finder response
/// carries code -8011 with empty text. Each endpoint's mapper decides which
/// codes matter.
class EfaSystemMessage {
  const EfaSystemMessage({required this.type, required this.code, this.text});

  final String type;
  final int code;
  final String? text;

  bool get isError => type == 'error';
}

/// Reads `systemMessages`. Entries without a type or code are skipped,
/// a missing array means there are no messages.
List<EfaSystemMessage> readSystemMessages(Map<String, Object?> json) {
  final messages = json['systemMessages'];
  if (messages is! List<Object?>) return const [];
  return [
    for (final message in messages)
      if (message case {'type': final String type, 'code': final int code})
        EfaSystemMessage(
          type: type,
          code: code,
          text: switch (message) {
            {'text': final String text} when text.isNotEmpty => text,
            _ => null,
          },
        ),
  ];
}

/// EFA answered, but reported an error in `systemMessages`. Thrown by
/// mappers and turned into a `ServerFailure` by the repository.
class EfaServerException implements Exception {
  const EfaServerException(this.code, [this.message]);

  final int code;
  final String? message;

  @override
  String toString() => 'EfaServerException($code, $message)';
}
