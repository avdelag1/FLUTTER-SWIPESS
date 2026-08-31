import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/localized_search_slang.dart';

void main() {
  test('Mexico AI field uses only the approved local hook', () {
    final hooks = LocalizedSearchSlang.expressionsForCountry('Mexico');
    final candidates = LocalizedSearchSlang.searchPromptCandidates(
      city: 'Tulum',
      country: 'Mexico',
    );

    expect(hooks, const ['¿Qué Pachuca por Toluca?']);
    for (final hook in hooks) {
      expect(candidates, contains(hook));
    }
    expect(candidates, isNot(contains('¿Qué rollo con el pollo?')));
    expect(candidates, isNot(contains('Relaja la raja')));
    expect(candidates, isNot(contains('Cámara')));
    expect(candidates, isNot(contains('Simón')));
    expect(candidates, contains('Show me something nearby'));
    expect(candidates, contains('Find a beautiful property in Tulum'));
    expect(candidates, contains('Find a trusted mechanic'));
  });

  test('localized slang uses shuffled hooks without immediate repeats', () {
    for (final country in const [
      'Mexico',
      'France',
      'Canada',
      'Spain',
      'Thailand',
      'United Arab Emirates',
      'USA',
    ]) {
      final allowed = LocalizedSearchSlang.expressionsForCountry(country).toSet();
      expect(allowed, isNotEmpty);

      String? previous;
      final seen = <String>{};
      for (var i = 0; i < 8; i++) {
        final prompt = LocalizedSearchSlang.searchPrompt(
          city: 'Test City',
          country: country,
        );
        expect(allowed, contains(prompt));
        if (previous != null && allowed.length > 1) {
          expect(prompt, isNot(previous));
        }
        previous = prompt;
        seen.add(prompt);
      }

      expect(seen, containsAll(allowed));
    }
  });

  test('requested countries mix local hooks into normal prompts', () {
    for (final country in const [
      'USA',
      'Mexico',
      'France',
      'Canada',
      'Spain',
      'Thailand',
      'United Arab Emirates',
    ]) {
      final candidates = LocalizedSearchSlang.searchPromptCandidates(
        city: 'Test City',
        country: country,
      );
      for (final hook in LocalizedSearchSlang.expressionsForCountry(country)) {
        expect(candidates, contains(hook));
      }
      expect(candidates, contains('Show me something nearby'));
      expect(candidates, contains('Find a beautiful property in Test City'));
    }
  });

  test('unknown country keeps neutral local fallback and normal candidates', () {
    expect(
      LocalizedSearchSlang.searchPrompt(
        city: 'Somewhere',
        country: 'Unknown',
      ),
      'What are you looking for?',
    );

    final candidates = LocalizedSearchSlang.searchPromptCandidates(
      city: 'Somewhere',
      country: 'Unknown',
    );
    expect(candidates, isNotEmpty);
    expect(candidates, contains('Show me something nearby'));
    expect(candidates, isNot(contains('¿Qué Pachuca por Toluca?')));
  });

  test('requested countries keep curated expression counts', () {
    expect(LocalizedSearchSlang.expressionsForCountry('Mexico'), hasLength(1));

    for (final country in const [
      'USA',
      'France',
      'Canada',
      'Spain',
      'Thailand',
      'United Arab Emirates',
    ]) {
      expect(LocalizedSearchSlang.expressionsForCountry(country), hasLength(2));
    }
  });
}
