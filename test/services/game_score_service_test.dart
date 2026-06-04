import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/models/board_cell.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/scoring_service.dart';
import 'package:kurdle_app/services/game_score_service.dart';

void main() {
  // Kurmanji harf puanları (frequency-based) — scoring_service.dart ile aynı.
  final scoring = ScoringService(kurdishLetterPoints);
  final service = GameScoreService(scoring);

  // Boş bir tahta üzerinde verilen hücreleri yerleştirip yeni WordBoard döner.
  // Her giriş: (row, col, letter, isPending, bonusType).
  WordBoard buildBoard(List<BoardCell> overrides) {
    var board = WordBoard.empty();
    for (final cell in overrides) {
      board = board.updateCell(cell);
    }
    return board;
  }

  // Kısa yol: tek hücre üreticisi.
  BoardCell cell(
    int row,
    int col,
    String letter, {
    bool pending = false,
    CellBonusType bonus = CellBonusType.none,
  }) {
    return BoardCell(
      row: row,
      column: col,
      letter: letter,
      isPending: pending,
      bonusType: bonus,
    );
  }

  group('GameScoreService.calculateNewWords — temel kelime bulma', () {
    test('Pending hücre yoksa boş liste döner', () {
      final board = WordBoard.empty();
      expect(service.calculateNewWords(board), isEmpty);
    });

    test('Tek izole pending harf (uzunluk 1) kelime saymaz', () {
      final board = buildBoard([
        cell(7, 7, 'A', pending: true),
      ]);
      expect(service.calculateNewWords(board), isEmpty);
    });

    test('Yatay iki pending harf "AN" -> tek kelime, skor 2', () {
      final board = buildBoard([
        cell(7, 7, 'A', pending: true),
        cell(7, 8, 'N', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      expect(words.length, 1);
      expect(words.first.word, 'AN');
      // A=1, N=1, bonus yok -> (1*1)+(1*1) = 2, wordMult=1
      expect(words.first.score, 2);
      expect(words.first.cells.length, 2);
    });

    test('Dikey iki pending harf "AL" -> tek kelime, skor 3 (L=2)', () {
      final board = buildBoard([
        cell(7, 7, 'A', pending: true),
        cell(8, 7, 'L', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      expect(words.length, 1);
      expect(words.first.word, 'AL');
      // A=1, L=2 -> 1+2 = 3
      expect(words.first.score, 3);
    });
  });

  group('GameScoreService.calculateNewWords — bonus kareler', () {
    test('doubleLetter pending hücre harf puanını 2x yapar', () {
      // "BA": B(=2) doubleLetter karede, A(=1) düz.
      final board = buildBoard([
        cell(7, 7, 'B', pending: true, bonus: CellBonusType.doubleLetter),
        cell(7, 8, 'A', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      expect(words.length, 1);
      // B=2 *2 (letterMult) = 4, A=1 -> 5, wordMult=1 (doubleLetter wordMult=1)
      expect(words.first.score, 5);
    });

    test('tripleLetter pending hücre harf puanını 3x yapar', () {
      // "BA": B(=2) tripleLetter, A(=1) düz.
      final board = buildBoard([
        cell(7, 7, 'B', pending: true, bonus: CellBonusType.tripleLetter),
        cell(7, 8, 'A', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      // B=2 *3 = 6, A=1 -> 7
      expect(words.first.score, 7);
    });

    test('doubleWord pending hücre kelime skorunu 2x yapar', () {
      // "AN": A doubleWord, N düz.
      final board = buildBoard([
        cell(7, 7, 'A', pending: true, bonus: CellBonusType.doubleWord),
        cell(7, 8, 'N', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      // (1 + 1) = 2, wordMult *= 2 -> 4
      expect(words.first.score, 4);
    });

    test('tripleWord pending hücre kelime skorunu 3x yapar', () {
      // "AN": A tripleWord, N düz.
      final board = buildBoard([
        cell(7, 7, 'A', pending: true, bonus: CellBonusType.tripleWord),
        cell(7, 8, 'N', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      // (1 + 1) = 2, wordMult *= 3 -> 6
      expect(words.first.score, 6);
    });

    test('start karesi doubleWord gibi davranır (wordMult=2)', () {
      // "AN": A start karesinde.
      final board = buildBoard([
        cell(7, 7, 'A', pending: true, bonus: CellBonusType.start),
        cell(7, 8, 'N', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      // (1 + 1) = 2, wordMult *= 2 -> 4
      expect(words.first.score, 4);
    });

    test('letterMult ve wordMult birlikte çarpılır (Q+A)', () {
      // "QA": Q(=8) doubleWord, A(=1) tripleLetter.
      final board = buildBoard([
        cell(7, 7, 'Q', pending: true, bonus: CellBonusType.doubleWord),
        cell(7, 8, 'A', pending: true, bonus: CellBonusType.tripleLetter),
      ]);
      final words = service.calculateNewWords(board);
      // Q: 8 * letterMult(1, doubleWord) = 8, wordMult *= 2
      // A: 1 * letterMult(3, tripleLetter) = 3, wordMult *= 1
      // toplam harf skoru = 11, wordMult = 2 -> 22
      expect(words.first.score, 22);
    });
  });

  group('GameScoreService.calculateNewWords — locked (kilitli) harf etkileşimi', () {
    test('Kilitli harf düz puan ekler, bonus/letterMult uygulanmaz', () {
      // "AN": A kilitli (commit edilmiş) ama doubleLetter karede, N pending.
      final board = buildBoard([
        cell(7, 7, 'A', pending: false, bonus: CellBonusType.doubleLetter),
        cell(7, 8, 'N', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      expect(words.length, 1);
      // A kilitli -> sadece pts=1 (letterMult yok), N pending -> 1
      // toplam = 2, wordMult=1
      expect(words.first.score, 2);
    });

    test('Kilitli harf doubleWord karede olsa bile wordMult etkilemez', () {
      // "AN": A kilitli doubleWord, N pending.
      final board = buildBoard([
        cell(7, 7, 'A', pending: false, bonus: CellBonusType.doubleWord),
        cell(7, 8, 'N', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      // wordMult kilitli hücrede çarpılmaz -> 2
      expect(words.first.score, 2);
    });

    test('Pending harf kilitli kelimeyi uzatır -> yeni kelime sayılır (ANT)', () {
      // Kilitli "AN" + pending "T" -> "ANT"
      final board = buildBoard([
        cell(7, 7, 'A', pending: false),
        cell(7, 8, 'N', pending: false),
        cell(7, 9, 'T', pending: true),
      ]);
      final words = service.calculateNewWords(board);
      expect(words.length, 1);
      expect(words.first.word, 'ANT');
      // A=1, N=1, T=1 (T pending letterMult=1) -> 3
      expect(words.first.score, 3);
    });

    test('Hiç pending olmayan kelime sonuca dahil edilmez', () {
      // Yatay kilitli "AN"; ayrıca uzak bir yere izole pending tek harf koy
      // (kelime oluşturmaz). Kilitli "AN" hiç pending içermediği için sayılmaz,
      // izole tek harf de uzunluk<2 olduğu için sayılmaz.
      final board = buildBoard([
        cell(7, 7, 'A', pending: false),
        cell(7, 8, 'N', pending: false),
        cell(0, 0, 'Z', pending: true),
      ]);
      expect(service.calculateNewWords(board), isEmpty);
    });
  });

  group('GameScoreService.calculateNewWords — çapraz (cross) kelimeler', () {
    test('Tek pending hücre hem yatay hem dikey kelime üretir', () {
      // (7,7) pending "A".
      // Yatay partner kilitli "N" (7,8) -> "AN"
      // Dikey partner kilitli "L" (8,7) -> "AL"
      final board = buildBoard([
        cell(7, 7, 'A', pending: true),
        cell(7, 8, 'N', pending: false),
        cell(8, 7, 'L', pending: false),
      ]);
      final words = service.calculateNewWords(board);
      expect(words.length, 2);
      final byWord = {for (final w in words) w.word: w.score};
      expect(byWord.containsKey('AN'), isTrue);
      expect(byWord.containsKey('AL'), isTrue);
      // AN: A pending(1) + N kilitli(1) = 2
      expect(byWord['AN'], 2);
      // AL: A pending(1) + L kilitli(2) = 3
      expect(byWord['AL'], 3);
    });

    test('Dikey "RAT": ortadaki harf pending, üst/alt kilitli', () {
      // (6,7) R kilitli, (7,7) A pending, (8,7) T kilitli.
      final board = buildBoard([
        cell(6, 7, 'R', pending: false),
        cell(7, 7, 'A', pending: true),
        cell(8, 7, 'T', pending: false),
      ]);
      final words = service.calculateNewWords(board);
      expect(words.length, 1);
      expect(words.first.word, 'RAT');
      // R=1, A=1, T=1 -> 3
      expect(words.first.score, 3);
    });
  });

  group('GameScoreService.totalScore — toplam skor', () {
    test('Boş liste toplamı 0', () {
      expect(GameScoreService.totalScore(const []), 0);
    });

    test('Birden fazla PlacedWord skoru toplanır', () {
      final words = [
        const PlacedWord(word: 'AN', score: 2, cells: []),
        const PlacedWord(word: 'AL', score: 3, cells: []),
        const PlacedWord(word: 'QA', score: 22, cells: []),
      ];
      expect(GameScoreService.totalScore(words), 27);
    });

    test('calculateNewWords çıktısının toplamı çapraz senaryoda 5', () {
      final board = buildBoard([
        cell(7, 7, 'A', pending: true),
        cell(7, 8, 'N', pending: false),
        cell(8, 7, 'L', pending: false),
      ]);
      final words = service.calculateNewWords(board);
      // AN(2) + AL(3) = 5
      expect(GameScoreService.totalScore(words), 5);
    });
  });
}
