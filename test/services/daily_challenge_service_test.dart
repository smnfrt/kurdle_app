import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/daily_challenge_service.dart';

void main() {
  group('ChallengeWord.masked', () {
    test('gizli index yokken kelime aynen döner', () {
      const w = ChallengeWord(
        original: 'MASKE',
        hiddenIndices: [],
        meaning: 'm',
        difficulty: ChallengeDifficulty.easy,
      );
      expect(w.masked, 'MASKE');
    });

    test('tek gizli index ilgili harfi alt çizgiyle değiştirir', () {
      const w = ChallengeWord(
        original: 'MASKE',
        hiddenIndices: [2],
        meaning: 'm',
        difficulty: ChallengeDifficulty.easy,
      );
      // index 2 = 'S' -> 'MA_KE'
      expect(w.masked, 'MA_KE');
    });

    test('birden çok gizli index hepsini maskeler', () {
      const w = ChallengeWord(
        original: 'MASKE',
        hiddenIndices: [0, 2, 4],
        meaning: 'm',
        difficulty: ChallengeDifficulty.medium,
      );
      // 0=M,2=S,4=E gizli -> '_A_K_'
      expect(w.masked, '_A_K_');
    });

    test('tüm harfler gizliyse hepsi alt çizgi olur', () {
      const w = ChallengeWord(
        original: 'DIL',
        hiddenIndices: [0, 1, 2],
        meaning: 'kalp',
        difficulty: ChallengeDifficulty.hard,
      );
      expect(w.masked, '___');
    });

    test('Kürtçe çok-byte harf (Ê) doğru maskelenir', () {
      const w = ChallengeWord(
        original: 'BÊ',
        hiddenIndices: [1],
        meaning: 'siz',
        difficulty: ChallengeDifficulty.easy,
      );
      // chars = [B, Ê]; index 1 gizli -> 'B_'
      expect(w.masked, 'B_');
    });
  });

  group('ChallengeWord.hiddenLetters', () {
    test('gizli indexlerdeki harfleri sırayla döner', () {
      const w = ChallengeWord(
        original: 'MASKE',
        hiddenIndices: [0, 2, 4],
        meaning: 'm',
        difficulty: ChallengeDifficulty.medium,
      );
      expect(w.hiddenLetters, ['M', 'S', 'E']);
    });

    test('boş gizli index boş liste döner', () {
      const w = ChallengeWord(
        original: 'MAL',
        hiddenIndices: [],
        meaning: 'ev',
        difficulty: ChallengeDifficulty.easy,
      );
      expect(w.hiddenLetters, isEmpty);
    });

    test('çok-byte Kürtçe harf doğru çıkarılır', () {
      const w = ChallengeWord(
        original: 'ŞEV',
        hiddenIndices: [0],
        meaning: 'gece',
        difficulty: ChallengeDifficulty.easy,
      );
      expect(w.hiddenLetters, ['Ş']);
    });
  });

  group('ChallengeWord.stageDuration', () {
    test('easy 5 saniye', () {
      const w = ChallengeWord(
        original: 'A',
        hiddenIndices: [],
        meaning: '',
        difficulty: ChallengeDifficulty.easy,
      );
      expect(w.stageDuration, const Duration(seconds: 5));
    });

    test('medium 7 saniye', () {
      const w = ChallengeWord(
        original: 'A',
        hiddenIndices: [],
        meaning: '',
        difficulty: ChallengeDifficulty.medium,
      );
      expect(w.stageDuration, const Duration(seconds: 7));
    });

    test('hard 10 saniye', () {
      const w = ChallengeWord(
        original: 'A',
        hiddenIndices: [],
        meaning: '',
        difficulty: ChallengeDifficulty.hard,
      );
      expect(w.stageDuration, const Duration(seconds: 10));
    });
  });

  group('ChallengeWord.stageIndex', () {
    test('easy=0, medium=1, hard=2', () {
      const easy = ChallengeWord(
        original: 'A',
        hiddenIndices: [],
        meaning: '',
        difficulty: ChallengeDifficulty.easy,
      );
      const medium = ChallengeWord(
        original: 'A',
        hiddenIndices: [],
        meaning: '',
        difficulty: ChallengeDifficulty.medium,
      );
      const hard = ChallengeWord(
        original: 'A',
        hiddenIndices: [],
        meaning: '',
        difficulty: ChallengeDifficulty.hard,
      );
      expect(easy.stageIndex, 0);
      expect(medium.stageIndex, 1);
      expect(hard.stageIndex, 2);
    });
  });

  group('DailyChallengeService.normalize', () {
    test('baştaki/sondaki boşlukları kırpar ve büyük harfe çevirir', () {
      expect(DailyChallengeService.normalize('  mal  '), 'MAL');
    });

    test('zaten normal kelime aynen döner', () {
      expect(DailyChallengeService.normalize('DIL'), 'DIL');
    });

    test('Kürtçe harfler büyük harfe çevrilir', () {
      expect(DailyChallengeService.normalize('şev'), 'ŞEV');
    });

    test('boş string boş döner', () {
      expect(DailyChallengeService.normalize('   '), '');
    });
  });

  group('DailyChallengeService.isCorrect', () {
    const challenge = ChallengeWord(
      original: 'MASKE',
      hiddenIndices: [0, 2, 4], // gizli harfler: M, S, E
      meaning: 'm',
      difficulty: ChallengeDifficulty.medium,
    );

    test('doğru sıra ve harflerle true döner', () {
      expect(DailyChallengeService.isCorrect(['M', 'S', 'E'], challenge), isTrue);
    });

    test('yanlış harf false döner', () {
      expect(DailyChallengeService.isCorrect(['M', 'X', 'E'], challenge), isFalse);
    });

    test('doğru harfler yanlış sırada false döner', () {
      expect(DailyChallengeService.isCorrect(['E', 'S', 'M'], challenge), isFalse);
    });

    test('eksik girdi (uzunluk uyuşmazlığı) false döner', () {
      expect(DailyChallengeService.isCorrect(['M', 'S'], challenge), isFalse);
    });

    test('fazla girdi (uzunluk uyuşmazlığı) false döner', () {
      expect(
        DailyChallengeService.isCorrect(['M', 'S', 'E', 'K'], challenge),
        isFalse,
      );
    });

    test('boş gizli index ve boş girdi true döner', () {
      const empty = ChallengeWord(
        original: 'MAL',
        hiddenIndices: [],
        meaning: 'ev',
        difficulty: ChallengeDifficulty.easy,
      );
      expect(DailyChallengeService.isCorrect([], empty), isTrue);
    });

    test('boş gizli index ama dolu girdi false döner', () {
      const empty = ChallengeWord(
        original: 'MAL',
        hiddenIndices: [],
        meaning: 'ev',
        difficulty: ChallengeDifficulty.easy,
      );
      expect(DailyChallengeService.isCorrect(['M'], empty), isFalse);
    });
  });

  group('DailyChallengeService.calcScore', () {
    // easy => (base 50, div 200), bonus = (ms/200).floor().clamp(0,50)
    test('easy, kalan süre 0 -> sadece base (50)', () {
      expect(DailyChallengeService.calcScore(ChallengeDifficulty.easy, 0), 50);
    });

    test('easy, kalan 5000ms -> 50 + 25 = 75', () {
      // 5000/200 = 25
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.easy, 5000),
        75,
      );
    });

    test('easy, çok yüksek süre bonus 50 ile sınırlanır -> 100', () {
      // 100000/200 = 500 -> clamp 50
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.easy, 100000),
        100,
      );
    });

    test('easy, negatif süre bonus 0 olur -> 50', () {
      // -100/200 = -0.5 -> floor -1 -> clamp(0,50)=0
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.easy, -100),
        50,
      );
    });

    // medium => (base 100, div 150)
    test('medium, kalan 0 -> base 100', () {
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.medium, 0),
        100,
      );
    });

    test('medium, kalan 7000ms -> 100 + 46 = 146', () {
      // 7000/150 = 46.66 -> floor 46
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.medium, 7000),
        146,
      );
    });

    // hard => (base 150, div 100)
    test('hard, kalan 0 -> base 150', () {
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.hard, 0),
        150,
      );
    });

    test('hard, kalan 4999ms -> 150 + 49 = 199', () {
      // 4999/100 = 49.99 -> floor 49
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.hard, 4999),
        199,
      );
    });

    test('hard, kalan 5000ms -> 150 + 50 = 200 (bonus tavanı)', () {
      // 5000/100 = 50 -> clamp 50
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.hard, 5000),
        200,
      );
    });

    test('hard, çok yüksek süre bonus 50 ile sınırlanır -> 200', () {
      expect(
        DailyChallengeService.calcScore(ChallengeDifficulty.hard, 999999),
        200,
      );
    });
  });

  group('DailyChallengeService.buildOptions', () {
    test('varsayılan total=8 -> tam 8 benzersiz harf döner', () {
      const w = ChallengeWord(
        original: 'MASKE',
        hiddenIndices: [0, 2], // gizli: M, S (2 doğru harf)
        meaning: 'm',
        difficulty: ChallengeDifficulty.medium,
      );
      final opts = DailyChallengeService.buildOptions(w);
      expect(opts.length, 8);
      expect(opts.toSet().length, 8, reason: 'tüm seçenekler benzersiz olmalı');
    });

    test('sonuç her zaman tüm doğru gizli harfleri içerir', () {
      const w = ChallengeWord(
        original: 'MASKE',
        hiddenIndices: [0, 2, 4], // gizli: M, S, E
        meaning: 'm',
        difficulty: ChallengeDifficulty.medium,
      );
      final opts = DailyChallengeService.buildOptions(w);
      expect(opts, containsAll(['M', 'S', 'E']));
    });

    test('özel total değeri ile o uzunlukta liste döner', () {
      const w = ChallengeWord(
        original: 'MAL',
        hiddenIndices: [0], // gizli: M
        meaning: 'ev',
        difficulty: ChallengeDifficulty.easy,
      );
      final opts = DailyChallengeService.buildOptions(w, total: 5);
      expect(opts.length, 5);
      expect(opts.toSet().length, 5);
      expect(opts, contains('M'));
    });

    test('tekrarlı gizli harfler benzersizleştirilir (set davranışı)', () {
      // 'MAMA': index 0 ve 2 ikisi de 'M' -> doğru set yalnız {M}
      const w = ChallengeWord(
        original: 'MAMA',
        hiddenIndices: [0, 2],
        meaning: 'test',
        difficulty: ChallengeDifficulty.easy,
      );
      final opts = DailyChallengeService.buildOptions(w, total: 6);
      expect(opts, contains('M'));
      expect(opts.toSet().length, opts.length, reason: 'hepsi benzersiz');
      expect(opts.length, 6);
    });

    test('total alfabe boyutundan büyükse en fazla alfabe+doğru kadar döner', () {
      // _kuAlphabet 30 harf; total çok yüksekse loop biter, set havuzla sınırlı.
      const w = ChallengeWord(
        original: 'MASKE',
        hiddenIndices: [0], // gizli: M (zaten alfabede)
        meaning: 'm',
        difficulty: ChallengeDifficulty.easy,
      );
      final opts = DailyChallengeService.buildOptions(w, total: 100);
      // Doğru harfler alfabede olduğu için toplam benzersiz <= 30
      expect(opts.length, lessThanOrEqualTo(30));
      expect(opts, contains('M'));
      expect(opts.toSet().length, opts.length);
    });
  });

  group('DailyChallengeService.getTodaysWords', () {
    test('tam 3 kelime döner', () {
      final words = DailyChallengeService.getTodaysWords();
      expect(words.length, 3);
    });

    test('zorluklar sırayla easy/medium/hard atanır', () {
      final words = DailyChallengeService.getTodaysWords();
      expect(words[0].difficulty, ChallengeDifficulty.easy);
      expect(words[1].difficulty, ChallengeDifficulty.medium);
      expect(words[2].difficulty, ChallengeDifficulty.hard);
    });

    test('aynı gün içinde deterministiktir (iki çağrı eşit kelimeler)', () {
      final a = DailyChallengeService.getTodaysWords();
      final b = DailyChallengeService.getTodaysWords();
      for (var i = 0; i < 3; i++) {
        expect(a[i].original, b[i].original);
        expect(a[i].hiddenIndices, b[i].hiddenIndices);
      }
    });

    test('her kelime normalize (büyük harf) ve en az 3 karakter', () {
      final words = DailyChallengeService.getTodaysWords();
      for (final w in words) {
        expect(w.original, w.original.toUpperCase());
        expect(w.original.length, greaterThanOrEqualTo(3));
      }
    });

    test('gizli index sayısı en az 1 ve kelime uzunluğundan küçüktür', () {
      final words = DailyChallengeService.getTodaysWords();
      for (final w in words) {
        final n = w.original.characters.length; // gerçek karakter sayısı
        expect(w.hiddenIndices.length, greaterThanOrEqualTo(1));
        expect(w.hiddenIndices.length, lessThan(n),
            reason: 'en az bir harf görünür kalmalı (clamp 1, n-1)');
      }
    });

    test('zorluk arttıkça gizli oran (yaklaşık) artar — hard >= easy', () {
      final words = DailyChallengeService.getTodaysWords();
      // easy 0.30, hard 0.70 oran -> aynı uzunlukta hard daha çok gizler.
      // Kelimeler farklı uzunlukta olabilir; oranla karşılaştır.
      double ratio(ChallengeWord w) =>
          w.hiddenIndices.length / w.original.characters.length;
      expect(ratio(words[2]) >= ratio(words[0]), isTrue,
          reason: 'hard oranı easy oranından küçük olmamalı');
    });

    test('üretilen kelimeler kendi gizli harfleriyle isCorrect doğrular', () {
      final words = DailyChallengeService.getTodaysWords();
      for (final w in words) {
        expect(DailyChallengeService.isCorrect(w.hiddenLetters, w), isTrue);
      }
    });
  });

  group('DailyChallengeService sabitleri', () {
    test('perfectBonus 150', () {
      expect(DailyChallengeService.perfectBonus, 150);
    });
  });
}
