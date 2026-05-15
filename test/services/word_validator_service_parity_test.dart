import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/word_validator_service.dart';
import 'package:kurdle_app/services/word_normalizer.dart';

/// PARİTE TESTİ — yeni wordlist eski 516 kelimelik
/// `assets/kurdish_dictionary.txt`'in tamamını kapsadığını doğrular.
///
/// Bu test, gzip wordlist'in tüm eski Scrabble doğrulamalarını koruduğundan
/// emin olmak için kritiktir.
void main() {
  test(
      'eski kurdish_dictionary.txt kelimelerinin tamamı yeni wordlist ile geçerli',
      () async {
    // Eski wordlist'i doğrudan oku (asset değil, dosyadan).
    final oldFile = File('assets/kurdish_dictionary.txt');
    if (!oldFile.existsSync()) {
      // Dosya kaldırılmışsa parite testi atlanır.
      // Pipeline koşulduktan sonra eski dosyanın silinmiş olması beklenebilir.
      return;
    }
    final oldWords = oldFile
        .readAsLinesSync()
        .map(WordNormalizer.normalize)
        .where((w) => w.isNotEmpty)
        .toSet();

    // Yeni wordlist gzipli. Doğrudan dekompres edip oku.
    final newGz = File('assets/ferheng/wordlist.txt.gz');
    expect(newGz.existsSync(), isTrue,
        reason: 'pipeline çalıştırılmadı: assets/ferheng/wordlist.txt.gz yok. '
            'cd tools/ferheng_pipeline && make all && make deploy-assets');
    final bytes = newGz.readAsBytesSync();
    final decoded = gzip.decode(bytes);
    final newWords = utf8
        .decode(decoded)
        .split('\n')
        .map(WordNormalizer.normalize)
        .where((w) => w.isNotEmpty)
        .toSet();

    final validator = WordValidatorService(newWords.toList());

    final missing = <String>[];
    for (final w in oldWords) {
      if (!validator.isValid(w)) missing.add(w);
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Yeni wordlist ${missing.length}/${oldWords.length} eski kelimeyi '
          'tanımıyor. İlk 10: ${missing.take(10).toList()}',
    );
  });

  test('yeni wordlist eski wordlist\'ten en az 100x daha büyük', () {
    final newGz = File('assets/ferheng/wordlist.txt.gz');
    if (!newGz.existsSync()) return;
    final bytes = newGz.readAsBytesSync();
    final decoded = gzip.decode(bytes);
    final newCount = utf8
        .decode(decoded)
        .split('\n')
        .where((w) => w.trim().isNotEmpty)
        .length;
    // Eski 516 kelimeydi; yeni en az 50,000 kelime olmalı (Hunspell expansion).
    expect(newCount, greaterThan(50000),
        reason: 'Yeni wordlist çok küçük: $newCount kelime');
  });
}
