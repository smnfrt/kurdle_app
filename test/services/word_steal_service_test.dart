import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/word_steal_service.dart';

void main() {
  const svc = WordStealService();

  group('Sabitler (stealBonus / minLength / maxSteals)', () {
    test('stealBonus 5, minLength 3, maxSteals 2 sabitleri', () {
      expect(WordStealService.stealBonus, 5);
      expect(WordStealService.minLength, 3);
      expect(WordStealService.maxSteals, 2);
    });
  });

  group('normalize() — trim + büyük harf', () {
    test('baştaki/sondaki boşlukları atar ve büyük harfe çevirir', () {
      expect(WordStealService.normalize('  roj  '), 'ROJ');
    });

    test('zaten büyük harf olanı değiştirmez', () {
      expect(WordStealService.normalize('ROJA'), 'ROJA');
    });

    test('Kürtçe küçük harfleri büyük hale getirir (î/ê/û/ç/ş)', () {
      expect(WordStealService.normalize('jîn'), 'JÎN');
      expect(WordStealService.normalize('şên'), 'ŞÊN');
      expect(WordStealService.normalize('  xwarinê '), 'XWARINÊ');
    });

    test('boş string boş kalır', () {
      expect(WordStealService.normalize('   '), '');
    });
  });

  group('getLetterCount() — harf sayımı', () {
    test('HEVAL doğru sayım', () {
      expect(WordStealService.getLetterCount('HEVAL'),
          {'H': 1, 'E': 1, 'V': 1, 'A': 1, 'L': 1});
    });

    test('ROJA doğru sayım', () {
      expect(WordStealService.getLetterCount('ROJA'),
          {'R': 1, 'O': 1, 'J': 1, 'A': 1});
    });

    test('tekrar eden harfleri sayar (AABBB)', () {
      expect(WordStealService.getLetterCount('AABBB'), {'A': 2, 'B': 3});
    });

    test('normalize uygular — küçük harf + boşluk', () {
      expect(WordStealService.getLetterCount('  roja '),
          {'R': 1, 'O': 1, 'J': 1, 'A': 1});
    });

    test('Kürtçe çok-baytlı harfler tek tek sayılır (ŞÊN)', () {
      // Ê, Î, Û, Ç, Ş precomposed tek grapheme — count 1 olmalı.
      expect(WordStealService.getLetterCount('ŞÊN'),
          {'Ş': 1, 'Ê': 1, 'N': 1});
    });

    test('Kürtçe harfli uzun kelime (XWARINÊ)', () {
      expect(WordStealService.getLetterCount('xwarinê'),
          {'X': 1, 'W': 1, 'A': 1, 'R': 1, 'I': 1, 'N': 1, 'Ê': 1});
    });

    test('boş string boş Map döner', () {
      expect(WordStealService.getLetterCount(''), <String, int>{});
    });
  });

  group('newLetterIndices() — yeni harf indeksleri', () {
    test('CAT → CATCH yeni harfler [3,4]', () {
      expect(WordStealService.newLetterIndices('CAT', 'CATCH'), [3, 4]);
    });

    test('ROJ → ROJA tek yeni harf [3]', () {
      expect(WordStealService.newLetterIndices('ROJ', 'ROJA'), [3]);
    });

    test('ROJ → BROJA başta ve sonda yeni [0,4]', () {
      expect(WordStealService.newLetterIndices('ROJ', 'BROJA'), [0, 4]);
    });

    test('greedy eşleşme — base harfleri sırayla tüketilir', () {
      // base AA -> next ABA: A(match,idx0), B(yeni,idx1), A(match,idx2) => [1]
      expect(WordStealService.newLetterIndices('AA', 'ABA'), [1]);
    });

    test('aynı uzunlukta hiç yeni harf yok ([])', () {
      expect(WordStealService.newLetterIndices('ROJ', 'JOR'), <int>[]);
    });

    test('normalize uygular — küçük harf girişte de çalışır', () {
      expect(WordStealService.newLetterIndices('roj', 'roja'), [3]);
    });

    test('Kürtçe çok-baytlı harf doğru indekslenir (ROJ → ROJÊ)', () {
      // R(match),O(match),J(match),Ê(yeni,idx3)
      expect(WordStealService.newLetterIndices('ROJ', 'ROJÊ'), [3]);
    });
  });

  group('canSteal() — başarılı çalmalar', () {
    test('ROJ → ROJA başarılı, +6 bonus, added 1, indices [3]', () {
      final r = svc.canSteal('ROJ', 'ROJA', currentSteals: 0);
      expect(r.success, isTrue);
      expect(r.baseWord, 'ROJ');
      expect(r.newWord, 'ROJA');
      expect(r.addedCount, 1);
      expect(r.bonusScore, 6); // 1 + stealBonus(5)
      expect(r.newIndices, [3]);
      expect(r.reason, '');
    });

    test('giriş normalize edilir (küçük harf + boşluk)', () {
      final r = svc.canSteal('  roj ', ' roja ');
      expect(r.success, isTrue);
      expect(r.baseWord, 'ROJ');
      expect(r.newWord, 'ROJA');
      expect(r.bonusScore, 6);
    });

    test('iki harf eklenince bonus +7 (CAT → CATCH)', () {
      final r = svc.canSteal('CAT', 'CATCH');
      expect(r.success, isTrue);
      expect(r.addedCount, 2);
      expect(r.bonusScore, 7); // 2 + 5
      expect(r.newIndices, [3, 4]);
    });

    test('baştan harf ekleme (ROJ → BROJA) çalışır', () {
      final r = svc.canSteal('ROJ', 'BROJA');
      expect(r.success, isTrue);
      expect(r.addedCount, 2);
      expect(r.newIndices, [0, 4]);
    });

    test('geçerli sözlük fonksiyonu true dönerse başarılı', () {
      final r = svc.canSteal('ROJ', 'ROJA',
          isValidWord: (w) => w == 'ROJA');
      expect(r.success, isTrue);
      expect(r.bonusScore, 6);
    });

    test('currentSteals=1 (limitin altında) başarılı', () {
      final r = svc.canSteal('ROJ', 'ROJA', currentSteals: 1);
      expect(r.success, isTrue);
    });

    test('Kürtçe harf ekleyerek çalma (ROJ → ROJÊ)', () {
      final r = svc.canSteal('ROJ', 'ROJÊ');
      expect(r.success, isTrue);
      expect(r.addedCount, 1);
      expect(r.bonusScore, 6);
      expect(r.newIndices, [3]);
    });

    test('Kürtçe base kelimeyi uzatma (ŞÊN → ŞÊNG)', () {
      final r = svc.canSteal('ŞÊN', 'ŞÊNG');
      expect(r.success, isTrue);
      expect(r.addedCount, 1);
      expect(r.bonusScore, 6);
      expect(r.newIndices, [3]); // G yeni
    });
  });

  group('canSteal() — başarısız: minimum uzunluk', () {
    test('2 harflik base reddedilir (RO → ROJ)', () {
      final r = svc.canSteal('RO', 'ROJ');
      expect(r.success, isFalse);
      expect(r.reason, contains('çok kısa'));
    });

    test('tam sınır: 3 harf kabul edilir (minLength dahil)', () {
      // ROJ tam 3 harf -> minLength kontrolünü geçmeli (success)
      final r = svc.canSteal('ROJ', 'ROJA');
      expect(r.success, isTrue);
    });
  });

  group('canSteal() — başarısız: çalma limiti', () {
    test('currentSteals=maxSteals(2) reddedilir', () {
      final r = svc.canSteal('ROJ', 'ROJA', currentSteals: 2);
      expect(r.success, isFalse);
      expect(r.reason, contains('zaten 2 kez çalındı'));
    });

    test('currentSteals limiti minLength sonrası kontrol edilir', () {
      // base çok kısa AMA currentSteals da dolu — minLength önce gelir.
      final r = svc.canSteal('RO', 'ROJ', currentSteals: 5);
      expect(r.success, isFalse);
      expect(r.reason, contains('çok kısa')); // limit değil, uzunluk mesajı
    });
  });

  group('canSteal() — başarısız: uzunluk artmamış', () {
    test('aynı uzunluk reddedilir (ROJA → JORA)', () {
      final r = svc.canSteal('ROJA', 'JORA');
      expect(r.success, isFalse);
      expect(r.reason, contains('uzun değil'));
    });

    test('daha kısa newWord reddedilir (ROJA → ROJ)', () {
      final r = svc.canSteal('ROJA', 'ROJ');
      expect(r.success, isFalse);
      expect(r.reason, contains('uzun değil'));
    });
  });

  group('canSteal() — başarısız: harf içerme yetersiz', () {
    test('base harfi newWord da eksik (AAB → ABXY)', () {
      // base A:2,B:1 ; next A:1 -> A yetersiz. next 4 harf, base 3 harf (uzunluk OK).
      final r = svc.canSteal('AAB', 'ABXY');
      expect(r.success, isFalse);
      expect(r.reason, contains('yetersiz'));
    });

    test('tek harf eksikliği bile reddeder (ROJ → XOJAB)', () {
      // base R:1,O:1,J:1 ; next X,O,J,A,B -> R yok -> yetersiz
      final r = svc.canSteal('ROJ', 'XOJAB');
      expect(r.success, isFalse);
      expect(r.reason, contains('yetersiz'));
    });

    test('Kürtçe harf içerme — Ê base da var next te yoksa reddeder', () {
      // base Ş,Ê,N ; next Ş,N,G,H (4 harf) -> Ê yok -> yetersiz
      final r = svc.canSteal('ŞÊN', 'ŞNGH');
      expect(r.success, isFalse);
      expect(r.reason, contains('yetersiz'));
    });
  });

  group('canSteal() — başarısız: sözlük kontrolü', () {
    test('isValidWord false dönerse reddedilir', () {
      final r = svc.canSteal('ROJ', 'ROJA', isValidWord: (_) => false);
      expect(r.success, isFalse);
      expect(r.reason, contains('sözlükte bulunamadı'));
    });

    test('isValidWord null ise sözlük kontrolü atlanır (başarılı)', () {
      final r = svc.canSteal('ROJ', 'ROJA', isValidWord: null);
      expect(r.success, isTrue);
    });

    test('sözlük kontrolü normalize edilmiş kelime ile çağrılır', () {
      String? seen;
      svc.canSteal(' roj ', ' roja ', isValidWord: (w) {
        seen = w;
        return true;
      });
      expect(seen, 'ROJA');
    });
  });

  group('StealResult — model davranışı', () {
    test('ok sonucunun toString formatı', () {
      final r = svc.canSteal('ROJ', 'ROJA');
      expect(r.toString(), 'StealResult.ok(ROJ → ROJA, +6)');
    });

    test('fail sonucunun toString formatı reason içerir', () {
      final r = svc.canSteal('RO', 'ROJ');
      expect(r.toString(), startsWith('StealResult.fail('));
      expect(r.toString(), contains('çok kısa'));
    });

    test('fail sonucunda bonusScore 0 ve newIndices boş', () {
      final r = svc.canSteal('ROJA', 'ROJ');
      expect(r.success, isFalse);
      expect(r.bonusScore, 0);
      expect(r.addedCount, 0);
      expect(r.newIndices, isEmpty);
    });
  });
}
