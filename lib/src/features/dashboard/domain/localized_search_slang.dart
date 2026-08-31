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

  /// Returns one item from the same mixed pool used by the dashboard field.
  ///
  /// The dashboard currently starts with its localized slot at index 0. By
  /// making that slot itself draw from the full mixed pool, a newly opened app
  /// no longer predictably shows the new slang first. Slang and the existing
  /// discovery prompts can all be the first visible phrase.
  static String searchPrompt({
    required String city,
    required String country,
  }) {
    final candidates = searchPromptCandidates(city: city, country: country);
    return candidates[_random.nextInt(candidates.length)];
  }

  /// Full candidate pool for the rotating dashboard AI field.
  ///
  /// Only the first two country expressions are promoted into this field; the
  /// remaining localisms stay available for future localized experiences.
  static List<String> searchPromptCandidates({
    required String city,
    required String country,
  }) {
    final cleanCity = city.trim().isEmpty ? 'your area' : city.trim();
    final expressions = expressionsForCountry(country);
    final local = expressions.take(2);

    return <String>[
      ...local,
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
  }

  /// Five curated expressions per requested country/region. The first two are
  /// the ones currently eligible for the empty AI-field rotation.
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
