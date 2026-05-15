import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/language_config.dart';

void main() {
  tearDown(() => L.set(AppLocale.ku));

  test('interface locale does not change game language config', () {
    L.set(AppLocale.ku);
    final kuAssets = LanguageConfig.current.wordAssets;
    final kuPoints = LanguageConfig.current.letterPoints;

    L.set(AppLocale.tr);

    expect(LanguageConfig.current.wordAssets, kuAssets);
    expect(LanguageConfig.current.letterPoints, kuPoints);
    expect(LanguageConfig.current.wordAssets,
        contains('assets/ferheng/wordlist.txt.gz'));
    expect(LanguageConfig.current.wordAssets,
        isNot(contains('assets/turkish_words.txt')));
    expect(LanguageConfig.current.letterPoints, containsPair('Ê', 5));
    expect(LanguageConfig.current.letterPoints, isNot(contains('Ğ')));
  });
}
