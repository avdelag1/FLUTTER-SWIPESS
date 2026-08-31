import 'package:flutter_swipes/src/features/ai/domain/local_brain_relevance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters unrelated local brain matches for person searches', () {
    const telecom = {
      'name': 'TULUM',
      'category': 'Operadores de servicios de telecomunicaciones alámbricas',
      'city': 'Tulum',
    };
    expect(
      localBrainRelevanceScore(telecom, 'best wise man in tulum'),
      lessThan(0.5),
    );
    expect(
      filterLocalBrainMatches(
        [telecom],
        'best wise man in tulum',
        specificPerson: true,
      ),
      isEmpty,
    );
  });

  test('detects AI no-match replies', () {
    expect(
      aiDeclinedContactMatch(
        "I'm sorry—I don't have a local contact in Tulum who fits that description.",
      ),
      isTrue,
    );
  });

  test('does not resurrect weak matches when filtering general queries', () {
    const weak = {
      'name': 'Random Shop',
      'category': 'Retail',
      'city': 'Tulum',
    };
    expect(
      filterLocalBrainMatches(
        [weak],
        'wise man helper',
        specificPerson: false,
      ),
      isEmpty,
    );
  });

  test('matches VIP tag phrases like wise man', () {
    const ezriyah = {
      'name': 'Ezriyah Ben Derrick',
      'tags': ['wise man', 'best wise man', 'mentor'],
      'city': 'Global',
    };
    expect(
      filterLocalBrainMatches(
        [ezriyah],
        'wise man in tulum',
        specificPerson: true,
      ),
      isNotEmpty,
    );
  });
}
