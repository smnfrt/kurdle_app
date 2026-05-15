import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/word_normalizer.dart';

void main() {
  group('WordNormalizer', () {
    test('trims and uppercases without stripping Kurdish characters', () {
      expect(WordNormalizer.normalize('  kitêb  '), 'KITÊB');
      expect(WordNormalizer.normalize(' şev û roj '), 'ŞEV Û ROJ');
    });

    test('collapses repeated whitespace', () {
      expect(WordNormalizer.normalize('av   û\tagir'), 'AV Û AGIR');
    });
  });
}
