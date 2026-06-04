import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/services/matching_service.dart';

/// MatchingService.matches(guess, answer) için kapsamlı unit testler.
///
/// Beklenen değerler matching_service.dart içindeki gerçek mantık izlenerek
/// elle hesaplandı:
///   1. Pozisyonel eşleşmeler (guess[i] == answer[i]) -> correct (yeşil).
///   2. Kalan guess harfleri sırayla, kalan answer harfleri içinde aranır;
///      bulunursa o answer harfi "tüketilir" ve present (sarı) olur.
///   3. Bulunamazsa absent (gri) kalır.
///   4. Sonuç index'e göre sıralanır, value'lar UPPERCASE döner.
///
/// Renk kodları: GameColor.correct = yeşil, present = sarı, absent = gri.

/// Sonucu kolay doğrulamak için harf->renk listesi çıkaran yardımcı.
List<GameColor> colorsOf(Iterable<Letter> result) =>
    result.map((l) => l.color).toList();

/// Sonuçtan büyük harf değerlerini birleştirip kelimeye çevirir.
String valuesOf(Iterable<Letter> result) =>
    result.map((l) => l.value).join();

void main() {
  group('MatchingService.matches - temel davranış', () {
    test('sonuç index sırasına göre sıralı döner', () {
      final result = MatchingService.matches('abcde', 'edcba').toList();
      for (var i = 0; i < result.length; i++) {
        expect(result[i].index, i, reason: 'index $i sırada olmalı');
      }
    });

    test('value alanları büyük harfe (UPPERCASE) çevrilir', () {
      final result = MatchingService.matches('hello', 'world').toList();
      expect(valuesOf(result), 'HELLO');
    });

    test('sonuç uzunluğu guess uzunluğuna eşit', () {
      final result = MatchingService.matches('apple', 'paper').toList();
      expect(result.length, 5);
    });
  });

  group('MatchingService.matches - tam eşleşme (hepsi yeşil)', () {
    test('guess == answer ise tüm harfler correct', () {
      final result = MatchingService.matches('apple', 'apple').toList();
      expect(colorsOf(result), [
        GameColor.correct,
        GameColor.correct,
        GameColor.correct,
        GameColor.correct,
        GameColor.correct,
      ]);
      expect(valuesOf(result), 'APPLE');
    });

    test('tek harf tam eşleşme', () {
      final result = MatchingService.matches('a', 'a').toList();
      expect(result.single.color, GameColor.correct);
      expect(result.single.value, 'A');
    });
  });

  group('MatchingService.matches - hiç eşleşme yok (hepsi gri)', () {
    test('ortak harf olmayan kelime tamamen absent', () {
      final result = MatchingService.matches('abc', 'xyz').toList();
      expect(colorsOf(result), [
        GameColor.absent,
        GameColor.absent,
        GameColor.absent,
      ]);
    });

    test('tek harf eşleşmiyorsa absent', () {
      final result = MatchingService.matches('a', 'b').toList();
      expect(result.single.color, GameColor.absent);
    });
  });

  group('MatchingService.matches - kısmi eşleşme (sarı)', () {
    test('doğru harf yanlış pozisyonda -> present', () {
      // guess=arc, answer=car : a(0) car icinde var ama 0.poz degil -> present
      //                          r(1) car icinde var ama 1.poz degil -> present
      //                          c(2) car icinde var ama 2.poz degil -> present
      final result = MatchingService.matches('arc', 'car').toList();
      expect(colorsOf(result), [
        GameColor.present,
        GameColor.present,
        GameColor.present,
      ]);
    });

    test('yeşil + sarı + gri karışımı (apple/paper)', () {
      // a(0)p(1)p(2)l(3)e(4) vs p(0)a(1)p(2)e(3)r(4)
      // Yeşil: index2 p==p
      // Kalan guess: a(0),p(1),l(3),e(4) | kalan answer: p(0),a(1),e(3),r(4)
      //   a(0) -> 'a' bulundu (present), a tüketilir
      //   p(1) -> 'p' bulundu (present), p tüketilir
      //   l(3) -> bulunamadı (absent)
      //   e(4) -> 'e' bulundu (present), e tüketilir
      final result = MatchingService.matches('apple', 'paper').toList();
      expect(colorsOf(result), [
        GameColor.present, // a
        GameColor.present, // p
        GameColor.correct, // p (yeşil)
        GameColor.absent, // l
        GameColor.present, // e
      ]);
      expect(valuesOf(result), 'APPLE');
    });
  });

  group('MatchingService.matches - tekrarlı harf (duplicate) mantığı', () {
    test('guess\'te çift harf, answer\'da tek -> sadece biri sarı (speed/abide)',
        () {
      // s(0)p(1)e(2)e(3)d(4) vs a(0)b(1)i(2)d(3)e(4)
      // Yeşil yok. Kalan answer: [a,b,i,d,e]
      //   s -> absent
      //   p -> absent
      //   e(2) -> 'e' bulundu (present), e tüketilir -> [a,b,i,d]
      //   e(3) -> 'e' kalmadı (absent)
      //   d(4) -> 'd' bulundu (present), d tüketilir
      final result = MatchingService.matches('speed', 'abide').toList();
      expect(colorsOf(result), [
        GameColor.absent, // s
        GameColor.absent, // p
        GameColor.present, // e (ilk e tüketir)
        GameColor.absent, // e (ikinci e için harf kalmadı)
        GameColor.present, // d
      ]);
    });

    test('answer\'da çift harf, guess\'te tek -> tek sarı (world/hello)', () {
      // h(0)e(1)l(2)l(3)o(4) vs w(0)o(1)r(2)l(3)d(4)
      // Yeşil: index3 l==l
      // Kalan guess: h(0),e(1),l(2),o(4) | kalan answer: w(0),o(1),r(2),d(4)
      //   h -> absent
      //   e -> absent
      //   l(2) -> answer kalanında 'l' yok (l zaten yeşilde tüketildi) -> absent
      //   o(4) -> 'o' bulundu (present)
      final result = MatchingService.matches('hello', 'world').toList();
      expect(colorsOf(result), [
        GameColor.absent, // h
        GameColor.absent, // e
        GameColor.absent, // l (eşleşecek l kalmadı)
        GameColor.correct, // l (yeşil)
        GameColor.present, // o
      ]);
      expect(valuesOf(result), 'HELLO');
    });

    test('aynı harf hem yeşil (doğru yer) hem sarı (yanlış yer) - khaki/kayak',
        () {
      // guess=kayak vs answer=khaki
      // k(0)a(1)y(2)a(3)k(4) vs k(0)h(1)a(2)k(3)i(4)
      // Yeşil: index0 k==k
      // Kalan guess: a(1),y(2),a(3),k(4) | kalan answer: h(1),a(2),k(3),i(4)
      //   a(1) -> 'a' bulundu (present) -> [h,k,i]
      //   y(2) -> bulunamadı (absent)
      //   a(3) -> 'a' kalmadı (absent)
      //   k(4) -> 'k' bulundu (present)
      final result = MatchingService.matches('kayak', 'khaki').toList();
      expect(colorsOf(result), [
        GameColor.correct, // k (yeşil, index0)
        GameColor.present, // a
        GameColor.absent, // y
        GameColor.absent, // a (ikinci a için harf kalmadı)
        GameColor.present, // k
      ]);
      expect(valuesOf(result), 'KAYAK');
    });

    test('çift yeşil harf + fazlalık gri (lulls/hello)', () {
      // l(0)u(1)l(2)l(3)s(4) vs h(0)e(1)l(2)l(3)o(4)
      // Yeşil: index2 l==l, index3 l==l
      // Kalan guess: l(0),u(1),s(4) | kalan answer: h(0),e(1),o(4)
      //   l(0) -> answer kalanında 'l' yok -> absent
      //   u(1) -> absent
      //   s(4) -> absent
      final result = MatchingService.matches('lulls', 'hello').toList();
      expect(colorsOf(result), [
        GameColor.absent, // l (eşleşecek l kalmadı)
        GameColor.absent, // u
        GameColor.correct, // l (yeşil)
        GameColor.correct, // l (yeşil)
        GameColor.absent, // s
      ]);
    });

    test('answer\'daki tüm tekrarlar tüketilince fazla guess harfi gri kalır',
        () {
      // guess=aaaaa vs answer=aabbb
      // a(0)..a(4) vs a(0)a(1)b(2)b(3)b(4)
      // Yeşil: index0 a==a, index1 a==a
      // Kalan guess: a(2),a(3),a(4) | kalan answer: b(2),b(3),b(4)
      //   a(2) -> 'a' yok (gri), a(3) -> gri, a(4) -> gri
      final result = MatchingService.matches('aaaaa', 'aabbb').toList();
      expect(colorsOf(result), [
        GameColor.correct, // a (yeşil)
        GameColor.correct, // a (yeşil)
        GameColor.absent, // a
        GameColor.absent, // a
        GameColor.absent, // a
      ]);
      expect(valuesOf(result), 'AAAAA');
    });
  });

  group('MatchingService.matches - kenar durumlar', () {
    test('boş guess ve boş answer -> boş sonuç', () {
      final result = MatchingService.matches('', '').toList();
      expect(result, isEmpty);
    });

    test('dönen Letter nesneleri doğru index ve value taşır', () {
      final result = MatchingService.matches('cat', 'dog').toList();
      expect(result[0].index, 0);
      expect(result[0].value, 'C');
      expect(result[1].index, 1);
      expect(result[1].value, 'A');
      expect(result[2].index, 2);
      expect(result[2].value, 'T');
    });

    test('present harf answer\'da fazla kez varsa yine tek sarı sayılmaz fazlalık',
        () {
      // guess=eerie vs answer=where
      // e(0)e(1)r(2)i(3)e(4) vs w(0)h(1)e(2)r(3)e(4)
      // Yeşil: index4 e==e
      // Kalan guess: e(0),e(1),r(2),i(3) | kalan answer: w(0),h(1),e(2),r(3)
      //   e(0) -> 'e' bulundu (present) -> [w,h,r]
      //   e(1) -> 'e' kalmadı (absent)
      //   r(2) -> 'r' bulundu (present)
      //   i(3) -> bulunamadı (absent)
      final result = MatchingService.matches('eerie', 'where').toList();
      expect(colorsOf(result), [
        GameColor.present, // e
        GameColor.absent, // e (ikinci e için harf kalmadı)
        GameColor.present, // r
        GameColor.absent, // i
        GameColor.correct, // e (yeşil)
      ]);
      expect(valuesOf(result), 'EERIE');
    });
  });
}
