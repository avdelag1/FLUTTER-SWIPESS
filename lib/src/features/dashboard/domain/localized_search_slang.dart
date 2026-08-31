import 'dart:math' as math;

/// Curated, user-facing localisms for the Dashboard AI search prompt.
///
/// These are presentation-only phrases. They must never contain private Local
/// Brain routing metadata. The AI can use its private brain for matching, while
/// this file only controls the playful text a user sees in the empty search
/// field for the selected discovery country/city.
///
/// IMPORTANT: slang hooks are intentionally standalone. Do not append a
/// translation or explanation to the local phrase itself.
class LocalizedSearchSlang {
  const LocalizedSearchSlang._();

  static final math.Random _random = math.Random();
  static final Map<String, List<String>> _shuffleBags = {};
  static final Map<String, String> _lastPrompt = {};

  /// Returns one localized phrase from a shuffled, non-repeating bag.
  ///
  /// Every supported country gets exactly two short local hooks with the same
  /// conversational intent: "what's up / what's going on?". The pair is
  /// shuffled before use and immediate repeats are avoided across reshuffles.
  static String searchPrompt({
    required String city,
    required String country,
  }) {
    final key = _countryKey(country);
    final expressions = expressionsForCountry(country);
    if (expressions.isEmpty) return 'What are you looking for?';

    var bag = _shuffleBags[key];
    if (bag == null || bag.isEmpty) {
      bag = List<String>.of(expressions)..shuffle(_random);

      final previous = _lastPrompt[key];
      if (previous != null && bag.length > 1 && bag.last == previous) {
        final last = bag.last;
        bag[bag.length - 1] = bag.first;
        bag[0] = last;
      }
      _shuffleBags[key] = bag;
    }

    final next = bag.removeLast();
    _lastPrompt[key] = next;
    return next;
  }

  /// Full mixed candidate pool available to the dashboard AI field.
  ///
  /// The two local hooks participate alongside the existing useful discovery
  /// prompts. The complete list is shuffled so local hooks do not always lead.
  static List<String> searchPromptCandidates({
    required String city,
    required String country,
  }) {
    final cleanCity = city.trim().isEmpty ? 'your area' : city.trim();
    final expressions = expressionsForCountry(country);

    final candidates = <String>[
      ...expressions,
      'Show me something nearby',
      'Find a beautiful property in $cleanCity',
      'What’s happening around $cleanCity tonight?',
      'Find a massage or wellness service near me',
      'Find trusted workers near me',
      'Show me homes for rent',
      'Find a trusted mechanic',
      'Show me yachts nearby',
      'Find motorcycles around $cleanCity',
      'Need local legal help in $cleanCity?',
      'What’s popular around $cleanCity right now?',
      'Show me something worth swiping',
    ];
    candidates.shuffle(_random);
    return candidates;
  }

  /// Exactly two short "what's up / what's going on?" hooks per market.
  static List<String> expressionsForCountry(String country) {
    switch (_countryKey(country)) {
      case 'mexico':
        return const [
          '¿Qué Pachuca por Toluca?',
          '¿Qué rollo con el pollo?',
        ];
      case 'france':
        return const [
          'Quoi de neuf ?',
          'Ça dit quoi ?',
        ];
      case 'canada':
        return const [
          "What's up, bud?",
          "How's she goin'?",
        ];
      case 'spain':
        return const [
          '¿Qué pasa, máquina?',
          '¿Qué tal, tronco?',
        ];
      case 'thailand':
        return const [
          'ว่าไง?',
          'เป็นไงบ้าง?',
        ];
      case 'uae':
        return const [
          'شو الأخبار؟',
          'شو السالفة؟',
        ];
      case 'usa':
        return const [
          "What's good?",
          "What's up?",
        ];
      default:
        return const [];
    }
  }

  static String _countryKey(String country) {
    final normalized = _normalize(country);
    if (normalized == 'mx' || normalized.contains('mexico')) return 'mexico';
    if (normalized == 'fr' || normalized.contains('france')) return 'france';
    if (normalized == 'ca' || normalized.contains('canada')) return 'canada';
    if (normalized == 'es' ||
        normalized.contains('spain') ||
        normalized.contains('espana')) {
      return 'spain';
    }
    if (normalized == 'th' || normalized.contains('thailand')) {
      return 'thailand';
    }
    if (normalized == 'ae' ||
        normalized.contains('united arab emirates') ||
        normalized == 'uae' ||
        normalized.contains('emirates') ||
        normalized.contains('dubai')) {
      return 'uae';
    }
    if (normalized == 'us' ||
        normalized == 'usa' ||
        normalized.contains('united states') ||
        normalized.contains('america')) {
      return 'usa';
    }
    return normalized;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('é', 'e')
      .replaceAll('á', 'a')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
