import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/app_locale.dart';

void main() {
  group('FerhengEntry', () {
    final fixture = {
      'headword': 'AV',
      'normalized': 'AV',
      'prefixes': ['A', 'AV'],
      'dialect': 'kmr',
      'pos': ['noun'],
      'ipa': 'av',
      'definitions': {
        'kmr': [
          {
            'gloss': 'şilaviya zelal',
            'examples': [
              {'text': 'Av tê vexwarin.', 'translation': 'Water is drunk.'}
            ],
          }
        ],
        'tr': [
          {'gloss': 'su', 'examples': []}
        ],
      },
      'etymology': 'Ji proto-Îranî *āp-',
      'categories': ['nature'],
      'related': ['AVÊ'],
      'audioUrl': null,
      'source': 'wiktionary+legacy',
      'sourceUrl': 'https://ku.wiktionary.org/wiki/av',
      'license': 'CC BY-SA 4.0',
      'version': 1,
    };

    test('fromJson reads all fields', () {
      final e = FerhengEntry.fromJson(fixture);
      expect(e.headword, 'AV');
      expect(e.normalized, 'AV');
      expect(e.prefixes, ['A', 'AV']);
      expect(e.pos, ['noun']);
      expect(e.ipa, 'av');
      expect(e.definitionsKmr.first.gloss, 'şilaviya zelal');
      expect(e.definitionsKmr.first.examples.first.text, 'Av tê vexwarin.');
      expect(e.definitionsTr.first.gloss, 'su');
      expect(e.etymology, 'Ji proto-Îranî *āp-');
      expect(e.categories, ['nature']);
      expect(e.related, ['AVÊ']);
      expect(e.license, 'CC BY-SA 4.0');
    });

    test('toJson roundtrip preserves all fields', () {
      final original = FerhengEntry.fromJson(fixture);
      final json = original.toJson();
      final roundtripped = FerhengEntry.fromJson(json);
      expect(roundtripped.headword, original.headword);
      expect(roundtripped.normalized, original.normalized);
      expect(roundtripped.definitionsKmr.first.gloss,
          original.definitionsKmr.first.gloss);
      expect(roundtripped.definitionsTr.first.gloss,
          original.definitionsTr.first.gloss);
      expect(roundtripped.categories, original.categories);
    });

    test('displayGloss returns preferred language', () {
      final e = FerhengEntry.fromJson(fixture);
      expect(e.displayGloss(AppLocale.tr), 'su');
      expect(e.displayGloss(AppLocale.ku), 'şilaviya zelal');
    });

    test('displayGloss falls back when preferred is empty', () {
      final entry = FerhengEntry(
        headword: 'TEST',
        normalized: 'TEST',
        definitionsTr: const [],
        definitionsKmr: const [FerhengDefinition(gloss: 'test KMR')],
      );
      expect(entry.displayGloss(AppLocale.tr), 'test KMR');
    });

    test('preserves Kurmanji diacritics through roundtrip', () {
      const word = 'KITÊB'; // includes Ê
      final entry = FerhengEntry(
        headword: word,
        normalized: word,
        definitionsTr: const [FerhengDefinition(gloss: 'kitap')],
      );
      final round = FerhengEntry.fromJson(entry.toJson());
      expect(round.headword, 'KITÊB');
      expect(round.headword.codeUnits, word.codeUnits);
    });

    test('hasAnyDefinition reflects presence of either language', () {
      const empty = FerhengEntry(headword: 'X', normalized: 'X');
      expect(empty.hasAnyDefinition, isFalse);
      final withTr = FerhengEntry(
        headword: 'X',
        normalized: 'X',
        definitionsTr: const [FerhengDefinition(gloss: 'something')],
      );
      expect(withTr.hasAnyDefinition, isTrue);
    });
  });
}
