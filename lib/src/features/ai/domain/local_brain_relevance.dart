const _stopWords = <String>{
  'the',
  'and',
  'for',
  'with',
  'from',
  'that',
  'this',
  'what',
  'where',
  'who',
  'find',
  'best',
  'near',
  'nearby',
  'local',
  'please',
  'want',
  'need',
  'looking',
  'around',
  'give',
  'show',
  'get',
  'can',
  'you',
  'me',
  'somebody',
  'someone',
  'something',
  'una',
  'uno',
  'unos',
  'unas',
  'que',
  'por',
  'para',
  'con',
  'del',
  'los',
  'las',
  'donde',
  'quien',
  'busco',
  'buscar',
  'mejor',
  'cerca',
  'locales',
  'alguien',
  'algo',
  'quiero',
  'necesito',
  'in',
  'at',
};

String normalizeSearchBlob(String input) => input
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9áéíóúñü\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

List<String> _meaningfulTokens(String query) {
  return normalizeSearchBlob(query)
      .split(' ')
      .where((token) => token.length >= 3 && !_stopWords.contains(token))
      .toList(growable: false);
}

double localBrainRelevanceScore(Map<String, dynamic> entry, String query) {
  final tags = <String>[
    entry['name']?.toString() ?? '',
    entry['category']?.toString() ?? '',
    entry['description']?.toString() ?? '',
    entry['recommendation_note']?.toString() ?? '',
    entry['city']?.toString() ?? '',
    entry['neighborhood']?.toString() ?? '',
    for (final tag in entry['tags'] as List? ?? const [])
      tag?.toString() ?? '',
    for (final tag in entry['auto_tags'] as List? ?? const [])
      tag?.toString() ?? '',
  ];
  final blob = normalizeSearchBlob(tags.join(' '));
  final tokens = _meaningfulTokens(query);
  if (tokens.isEmpty || blob.isEmpty) return 0;

  var hits = 0;
  for (final token in tokens) {
    if (blob.contains(token)) {
      hits++;
    } else if (token.length >= 5 && blob.contains(token.substring(0, token.length - 2))) {
      hits++;
    } else if (token.length >= 4 && blob.contains(token.substring(0, token.length - 1))) {
      hits++;
    }
  }
  return hits / tokens.length;
}

bool aiDeclinedContactMatch(String text) {
  final normalized = text.toLowerCase();
  if (normalized.trim().isEmpty) return false;
  final declined = RegExp(
    r"(don'?t have|couldn'?t find|no trusted|no local contact|doesn'?t fit|not find anyone|sorry[\s\S]{0,80}don'?t have)",
    caseSensitive: false,
  ).hasMatch(normalized);
  if (!declined) return false;
  return RegExp(
    r'(match|contact|fit|description|directory|person|someone)',
    caseSensitive: false,
  ).hasMatch(normalized);
}

List<Map<String, dynamic>> filterLocalBrainMatches(
  List<Map<String, dynamic>> rows,
  String query, {
  required bool specificPerson,
}) {
  if (rows.isEmpty) return rows;
  final minScore = specificPerson ? 0.5 : 0.28;
  final filtered = rows
      .where((row) => localBrainRelevanceScore(row, query) >= minScore)
      .toList(growable: false);
  return filtered;
}
