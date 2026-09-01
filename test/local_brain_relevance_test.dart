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

  test('mentorship Tulum selects Mantorship instead of a Tulum directory entry', () {
    const mantorship = {
      'name': 'Mantorship',
      'category': "Men's community, brotherhood & personal growth",
      'city': 'Tulum',
      'tags': ['mentorship', 'man group', 'mens group', 'brotherhood', 'tulum'],
      'recommendation_note': 'A supportive men community and mentorship group in Tulum.',
    };
    const telecom = {
      'name': 'TULUM',
      'category': 'Operadores de servicios de telecomunicaciones alámbricas',
      'city': 'Tulum',
      'tags': ['tulum', 'official'],
    };

    final matches = filterLocalBrainMatches(
      [mantorship, telecom],
      'mentorship Tulum',
      specificPerson: true,
    );

    expect(matches, hasLength(1));
    expect(matches.single['name'], 'Mantorship');
  });

  test('best man group in Tulum keeps Mantorship above generic GROUP businesses', () {
    const mantorship = {
      'name': 'Mantorship',
      'category': "Men's community, brotherhood & personal growth",
      'city': 'Tulum',
      'tags': ['man group', 'best man group', 'mens group', 'brotherhood'],
    };
    const dentalGroup = {
      'name': 'CONSULTORIO DENTAL SMILE GROUP',
      'category': 'Dental clinic',
      'city': 'Tulum',
      'auto_tags': ['group', 'tulum', 'business'],
    };

    final matches = filterLocalBrainMatches(
      [mantorship, dentalGroup],
      'Best man group in Tulum?',
      specificPerson: true,
    );

    expect(matches, hasLength(1));
    expect(matches.single['name'], 'Mantorship');
  });

  test('whole word scoring does not treat man as part of Mango', () {
    const mango = {
      'name': 'Mango',
      'category': 'Hotel',
      'city': 'Tulum',
    };
    expect(
      localBrainRelevanceScore(mango, 'man group'),
      lessThan(0.5),
    );
  });
}
