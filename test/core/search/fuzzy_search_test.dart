import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/search/fuzzy_search.dart';

void main() {
  const spots = [
    ('Hundred Islands National Park', 'Alaminos'),
    ('Patar White Beach', 'Bolinao'),
    ('Manleluag Spring', 'Mangatarem'),
    ('Our Lady of Manaoag Basilica', 'Manaoag'),
  ];
  List<String> names(String q) => FuzzySearch.filter(
        spots,
        q,
        (s) => [s.$1, s.$2],
      ).map((s) => s.$1).toList();

  test('empty query keeps every item in order', () {
    expect(names(''), spots.map((s) => s.$1).toList());
    expect(names('   '), hasLength(4));
  });

  test('substring and prefix match', () {
    expect(names('hund'), ['Hundred Islands National Park']);
    expect(names('beach'), ['Patar White Beach']);
    expect(names('bolinao'), ['Patar White Beach']);
  });

  test('tolerates spelling mistakes', () {
    expect(names('hundered'), ['Hundred Islands National Park']);
    expect(names('manaog'), ['Our Lady of Manaoag Basilica']);
    expect(names('basilca'), ['Our Lady of Manaoag Basilica']);
    expect(names('patra'), ['Patar White Beach']);
  });

  test('every word must match; nonsense matches nothing', () {
    expect(names('white islands'), isEmpty);
    expect(names('zzzzqq'), isEmpty);
  });

  test('accents and punctuation are ignored', () {
    expect(FuzzySearch.score('manaoag', ['Manáoag!']), isNotNull);
    expect(FuzzySearch.normalize('Señor  Café'), 'senor cafe');
  });

  test('an exact name match ranks first', () {
    final r = FuzzySearch.filter(
      ['Manaoag Church', 'Manleluag', 'Manaoag'],
      'manaoag',
      (s) => [s],
    );
    expect(r.first, 'Manaoag');
    expect(r, isNot(contains('Manleluag')));
  });
}
