import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_swipes/src/features/dashboard/domain/localized_search_slang.dart';

void main() {
  test('Mexico prompt uses curated rhyme and current city', () {
    expect(
      LocalizedSearchSlang.searchPrompt(city: 'Tulum', country: 'Mexico'),
      '¿Qué Pachuca por Toluca? What are you looking for in Tulum?',
    );
  });

  test('Dubai/UAE prompt uses Yalla and current city', () {
    expect(
      LocalizedSearchSlang.searchPrompt(
        city: 'Dubai',
        country: 'United Arab Emirates',
      ),
      'Yalla — what are you looking for in Dubai?',
    );
  });

  test('Thailand prompt uses Thai casual greeting', () {
    expect(
      LocalizedSearchSlang.searchPrompt(city: 'Bangkok', country: 'Thailand'),
      'ไปไหน? What are you looking for in Bangkok?',
    );
  });

  test('USA can use city-aware regional hook', () {
    expect(
      LocalizedSearchSlang.searchPrompt(
        city: 'San Francisco',
        country: 'United States',
      ),
      'Hella ready? What are you looking for in San Francisco?',
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
