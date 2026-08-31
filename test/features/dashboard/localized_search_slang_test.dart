import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/localized_search_slang.dart';

void main() {
  test('Mexico prompt rotates standalone local slang only', () {
    for (var i = 0; i < 20; i++) {
      final prompt = LocalizedSearchSlang.searchPrompt(
        city: 'Tulum',
        country: 'Mexico',
      );
      expect(
        prompt,
        anyOf(
          '¿Qué Pachuca, Portoluca?',
          '¿Qué rollo con el pollo?',
        ),
      );
      expect(prompt, isNot(contains('What are you looking for')));
      expect(prompt, isNot(contains('Tulum')));
    }
  });

  test('requested countries use one of two standalone rotating hooks', () {
    final expected = <String, Set<String>>{
      'France': {'Ça roule, ma poule?', 'Tranquille, Émile?'},
      'Canada': {"How's she goin'?", "Give'r!"},
      'Spain': {'¿Qué pasa, máquina?', '¿Qué tal, tronco?'},
      'Thailand': {'เป็นไงบ้าง?', 'ชิลๆ'},
      'United Arab Emirates': {'Yalla habibi', 'Mafi mushkila'},
      'USA': {"What's good?", "What's the move?"},
    };

    for (final entry in expected.entries) {
      for (var i = 0; i < 10; i++) {
        final prompt = LocalizedSearchSlang.searchPrompt(
          city: 'Test City',
          country: entry.key,
        );
        expect(entry.value, contains(prompt));
        expect(prompt, isNot(contains('What are you looking for')));
        expect(prompt, isNot(contains('Test City')));
      }
    }
  });

  test('unknown country keeps a neutral fallback', () {
    expect(
      LocalizedSearchSlang.searchPrompt(
        city: 'Somewhere',
        country: 'Unknown',
      ),
      'What are you looking for?',
    );
  });

  test('requested countries keep five curated expressions', () {
    for (final country in const [
      'USA',
      'Mexico',
      'France',
      'Canada',
      'Spain',
      'Thailand',
      'United Arab Emirates',
    ]) {
      expect(LocalizedSearchSlang.expressionsForCountry(country), hasLength(5));
    }
  });
}
