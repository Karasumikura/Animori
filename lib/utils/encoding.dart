import 'dart:convert';

final RegExp _animoriRuleLinkSchemePattern = RegExp(
  r'animori:(?://)?',
  caseSensitive: false,
);

Iterable<({String scheme, String rawPayload})> findAnimoriRuleLinkSegments(
  String input,
) sync* {
  final matches = _animoriRuleLinkSchemePattern.allMatches(input).toList();
  for (var index = 0; index < matches.length; index++) {
    final match = matches[index];
    final end = index + 1 < matches.length
        ? matches[index + 1].start
        : input.length;
    yield (
      scheme: match.group(0)!,
      rawPayload: input.substring(match.end, end),
    );
  }
}

String jsonToAnimoriBase64(String jsonStr) {
  final base64Str = base64Encode(utf8.encode(jsonStr));
  return 'animori://$base64Str';
}

String animoriBase64ToJson(String animoriBase64Str) {
  final input = animoriBase64Str.trim();
  final schemeMatch = _animoriRuleLinkSchemePattern.matchAsPrefix(input);
  if (schemeMatch == null) {
    throw const FormatException('Invalid Animori rule link');
  }

  var payload = input.substring(schemeMatch.end);
  try {
    payload = Uri.decodeComponent(payload);
  } on FormatException {
    throw const FormatException('Invalid encoding in Animori rule link');
  } on ArgumentError {
    throw const FormatException('Invalid encoding in Animori rule link');
  }
  payload = payload.replaceAll(RegExp(r'\s'), '');
  if (payload.isEmpty) {
    throw const FormatException('Animori rule link is empty');
  }

  // Accept both standard and URL-safe Base64, with or without padding. Links
  // are frequently wrapped by chat applications or percent-encoded by URI
  // handlers before they reach the import dialog.
  final normalized = base64.normalize(
    payload.replaceAll('-', '+').replaceAll('_', '/'),
  );
  try {
    return utf8.decode(base64.decode(normalized));
  } on FormatException {
    throw const FormatException('Invalid Animori rule link payload');
  }
}
