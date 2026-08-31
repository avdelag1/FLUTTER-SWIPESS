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
}
