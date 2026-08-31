import 'dart:math' as math;

/// Curated, user-facing localisms for the Dashboard AI search prompt.
///
/// These are presentation-only phrases. They must never contain private Local
/// Brain routing metadata. The AI can use its private brain for matching, while
/// this file only controls the playful text a user sees in the empty search
/// field for the selected discovery country/city.
///
/// IMPORTANT: slang hooks are intentionally standalone. Do not append a
/// translation, explanation, city name, or "what are you looking for" copy.
class LocalizedSearchSlang {
  const LocalizedSearchSlang._();

  static final math.Random _random = math.Random();

  static String searchPrompt({
    required String city,
    required String country,
  }) {
    final expressions = expressionsForCountry(country);
    if (expressions.isEmpty) return 'What are you looking for?';

    // Keep the dashboard rotation light: only the first two curated localisms
    // participate in the AI-field rotation. The rest remain available for
    // future localized experiences without flooding the placeholder carousel.
    final visibleCount = expressions.length >= 2 ? 2 : expressions.length;
    return expressions[_random.nextInt(visibleCount)];
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
