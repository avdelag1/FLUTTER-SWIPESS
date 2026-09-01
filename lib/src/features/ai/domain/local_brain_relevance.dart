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

const _genericVipTags = <String>{
  'local',
  'business',
  'local business',
  'contact',
  'contacts',
  'people',
  'person',
  'someone',
  'professional',
  'professionals',
  'expert',
  'experts',
  'specialist',
  'specialists',
  'service',
  'services',
  'hire',
  'activity',
  'location',
  'place',
  'spot',
  'group',
  'club',
  'mexico',
  'mexican',
  'quintana roo',
  'global',
  'english',
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

Set<String> _blobWords(String blob) => normalizeSearchBlob(blob)
    .split(' ')
    .where((word) => word.length >= 3)
    .toSet();

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
  final words = _blobWords(blob);
  final tokens = _meaningfulTokens(query);
  if (tokens.isEmpty || blob.isEmpty) return 0;

  var hits = 0;
  for (final token in tokens) {
    if (words.contains(token)) {
      hits++;
      continue;
    }
    final fuzzyHit = words.any((word) {
      if (token.length >= 5 && word.startsWith(token.substring(0, token.length - 2))) {
        return true;
      }
      if (token.length >= 4 && word.startsWith(token.substring(0, token.length - 1))) {
        return true;
      }
      return false;
    });
    if (fuzzyHit) hits++;
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

Set<String> _locationWords(Map<String, dynamic> entry) {
  final values = <String>[
    entry['city']?.toString() ?? '',
    entry['region']?.toString() ?? '',
    entry['country']?.toString() ?? '',
  ];
  final result = <String>{};
  for (final value in values) {
    final normalized = normalizeSearchBlob(value);
    if (normalized.isEmpty) continue;
    result.add(normalized);
    result.addAll(normalized.split(' ').where((word) => word.length >= 3));
  }
  return result;
}

bool tagPhraseMatchesEntry(Map<String, dynamic> entry, String query) {
  final q = normalizeSearchBlob(query);
  final paddedQuery = ' $q ';
  final locationWords = _locationWords(entry);
  final tags = <String>[
    for (final tag in entry['tags'] as List? ?? const [])
      tag?.toString() ?? '',
    for (final tag in entry['auto_tags'] as List? ?? const [])
      tag?.toString() ?? '',
  ];
  for (final tag in tags) {
    final t = normalizeSearchBlob(tag);
    if (t.length < 4 || _genericVipTags.contains(t) || locationWords.contains(t)) {
      continue;
    }
    if (paddedQuery.contains(' $t ')) return true;
  }
  return false;
}

List<Map<String, dynamic>> filterLocalBrainMatches(
  List<Map<String, dynamic>> rows,
  String query, {
  required bool specificPerson,
}) {
  if (rows.isEmpty) return rows;
  final vipTagged = rows
      .where((row) => tagPhraseMatchesEntry(row, query))
      .toList(growable: false);
  if (vipTagged.isNotEmpty) {
    return specificPerson ? vipTagged.take(1).toList(growable: false) : vipTagged;
  }
  final minScore = specificPerson ? 0.5 : 0.28;
  final filtered = rows
      .where((row) => localBrainRelevanceScore(row, query) >= minScore)
      .toList(growable: false);
  return specificPerson ? filtered.take(1).toList(growable: false) : filtered;
}
