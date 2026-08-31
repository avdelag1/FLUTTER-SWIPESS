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
  /// Every country gets its own bag. The full local set is shuffled before use,
  /// consumed one item at a time, then reshuffled. This prevents the UI from
  /// always showing newly added phrases first and avoids immediate repeats.
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
      if (previous != null && bag.length > 1 && bag.first == previous) {
        final swapIndex = 1 + _random.nextInt(bag.length - 1);
        final first = bag.first;
        bag[0] = bag[swapIndex];
        bag[swapIndex] = first;
      }
      _shuffleBags[key] = bag;
    }

    final next = bag.removeLast();
    _lastPrompt[key] = next;
    return next;
  }

  /// Full mixed candidate pool available to the dashboard AI field.
  ///
  /// All local expressions participate, alongside the existing useful search
  /// prompts. Callers may shuffle this complete list when they need a one-shot
  /// randomized sequence.
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

  /// Five curated expressions per requested country/region.
  static List<String> expressionsForCountry(String country) {
    switch (_countryKey(country)) {
      case 'mexico':
        return const [
          '¿Qué Pachuca, Portoluca?',
          '¿Qué rollo con el pollo?',
          'Relaja la raja',
          'Cámara',
          'Simón',
        ];
      case 'france':
        return const [
          'Ça roule, ma poule?',
          'Tranquille, Émile?',
          'Ça marche',
          'Nickel',
          "Comme d'hab",
        ];
      case 'canada':
        return const [
          "How's she goin'?",
          "Give'r!",
          'No worries',
          'Beauty',
          'Eh?',
        ];
      case 'spain':
        return const [
          '¿Qué pasa, máquina?',
          '¿Qué tal, tronco?',
          'Qué guay',
          'Mola',
          'Vale',
        ];
      case 'thailand':
        return const [
          'เป็นไงบ้าง?',
          'ชิลๆ',
          'ไปไหน?',
          'กินข้าวหรือยัง?',
          'หวัดดี',
        ];
      case 'uae':
        return const [
          'Yalla habibi',
          'Mafi mushkila',
          'Khalas',
          'Marhaba',
          'Mashallah',
        ];
      case 'usa':
        return const [
          "What's good?",
          "What's the move?",
          "Y'all",
          'Hella',
          'You good?',
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
