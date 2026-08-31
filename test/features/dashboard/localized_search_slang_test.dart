import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/localized_search_slang.dart';

void main() {
  test('Mexico AI field mixes slang with existing discovery prompts', () {
    final candidates = LocalizedSearchSlang.searchPromptCandidates(
      city: 'Tulum',
      country: 'Mexico',
    );

    expect(candidates, contains('¿Qué Pachuca, Portoluca?'));
    expect(candidates, contains('¿Qué rollo con el pollo?'));
    expect(candidates, contains('Show me something nearby'));
    expect(candidates, contains('Find a beautiful property in Tulum'));
    expect(candidates, contains('Find a trusted mechanic'));

    for (var i = 0; i < 40; i++) {
      expect(
        candidates,
        contains(
          LocalizedSearchSlang.searchPrompt(city: 'Tulum', country: 'Mexico'),
        ),
      );
    }
  });

  test('requested countries mix their first two local hooks into normal prompts', () {
    final expected = <String, Set<String>>{
      'France': {'Ça roule, ma poule?', 'Tranquille, Émile?'},
      'Canada': {"How's she goin'?", "Give'r!"},
      'Spain': {'¿Qué pasa, máquina?', '¿Qué tal, tronco?'},
      'Thailand': {'เป็นไงบ้าง?', 'ชิลๆ'},
      'United Arab Emirates': {'Yalla habibi', 'Mafi mushkila'},
      'USA': {"What's good?", "What's the move?"},
    };

    for (final entry in expected.entries) {
      final candidates = LocalizedSearchSlang.searchPromptCandidates(
        city: 'Test City',
        country: entry.key,
      );
      for (final hook in entry.value) {
        expect(candidates, contains(hook));
      }
      expect(candidates, contains('Show me something nearby'));
      expect(candidates, contains('Find a beautiful property in Test City'));
    }
  });

  test('unknown country still gets the normal mixed discovery prompts', () {
    final candidates = LocalizedSearchSlang.searchPromptCandidates(
      city: 'Somewhere',
      country: 'Unknown',
    );
    expect(candidates, isNotEmpty);
    expect(candidates, contains('Show me something nearby'));
    expect(candidates, isNot(contains('¿Qué Pachuca, Portoluca?')));
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
