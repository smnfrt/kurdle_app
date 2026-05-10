import 'package:characters/characters.dart';

// ════════════════════════════════════════════════════════════════
//  STEAL RESULT — çalma kontrolünün sonuç modeli
// ════════════════════════════════════════════════════════════════

class StealResult {
  /// Çalma gerçekleşebilir mi?
  final bool success;

  /// Çalınan (orijinal) kelime — normalize edilmiş
  final String baseWord;

  /// Yeni (uzatılmış) kelime — normalize edilmiş
  final String newWord;

  /// Başarısızlık nedeni (success=false ise dolu)
  final String reason;

  /// Kaç harf eklendi
  final int addedCount;

  /// Toplam çalma bonusu: addedCount + stealBonus
  final int bonusScore;

  /// [newWord] içinde [baseWord]'e ek olarak gelen harflerin 0-tabanlı indeksleri.
  /// UI bu liste ile yeni harfleri farklı renkte gösterebilir.
  final List<int> newIndices;

  const StealResult._({
    required this.success,
    required this.baseWord,
    required this.newWord,
    this.reason     = '',
    this.addedCount = 0,
    this.bonusScore = 0,
    this.newIndices = const [],
  });

  factory StealResult.fail(String base, String next, String reason) =>
      StealResult._(success: false, baseWord: base, newWord: next, reason: reason);

  factory StealResult.ok({
    required String baseWord,
    required String newWord,
    required int addedCount,
    required List<int> newIndices,
  }) =>
      StealResult._(
        success:    true,
        baseWord:   baseWord,
        newWord:    newWord,
        addedCount: addedCount,
        bonusScore: addedCount + WordStealService.stealBonus,
        newIndices: newIndices,
      );

  @override
  String toString() => success
      ? 'StealResult.ok($baseWord → $newWord, +$bonusScore)'
      : 'StealResult.fail("$reason")';
}

// ════════════════════════════════════════════════════════════════
//  WORD STEAL SERVICE — saf çalma mantığı (UI/controller bağımsız)
// ════════════════════════════════════════════════════════════════

/// Kelime çalma kurallarını uygulayan stateless servis.
///
/// **Çalma koşulları** (hepsi sağlanmalı):
///  1. [baseWord] en az [minLength] (3) harf içermeli.
///  2. [newWord], [baseWord]'den en az 1 harf uzun olmalı.
///  3. [newWord], [baseWord]'deki **tüm harfleri** içermeli (Map bazlı sayım).
///  4. [isValidWord] verildiyse [newWord] sözlükte bulunmalı.
///  5. [currentSteals] < [maxSteals] (kelime henüz çok çalınmamış).
///
/// **Puanlama:** eklenen harf sayısı + [stealBonus] (sabit 5).
///
/// Örnek kullanım:
/// ```dart
/// final svc = const WordStealService();
///
/// // Temel kontrol
/// final r = svc.canSteal(
///   'ROJ',           // base: rakibin kelimesi
///   'ROJA',          // new: oyuncunun önerisi
///   isValidWord: validator.isValid,
///   currentSteals: 0,
/// );
/// print(r); // StealResult.ok(ROJ → ROJA, +6)
///
/// // Harf sayımı
/// print(WordStealService.getLetterCount('HEVAL'));
/// // {H:1, E:1, V:1, A:1, L:1}
/// ```
class WordStealService {
  const WordStealService();

  /// Çalma başına sabit bonus puan
  static const int stealBonus = 5;

  /// Çalınabilir minimum kelime uzunluğu
  static const int minLength = 3;

  /// Bir kelime en fazla kaç kez çalınabilir
  static const int maxSteals = 2;

  // ── Yardımcılar ──────────────────────────────────────────────

  /// Kelimeyi normalize eder: trim + büyük harf.
  ///
  /// ```dart
  /// normalize('  roj  ') // 'ROJ'
  /// ```
  static String normalize(String word) => word.trim().toUpperCase();

  /// Kelimedeki her harfin sayısını döndürür.
  ///
  /// Çok-baytlı karakterleri (`package:characters`) destekler,
  /// Kürmancî özel harfleri (Ê, Î, Û…) doğru sayar.
  ///
  /// ```dart
  /// getLetterCount('HEVAL') // {H:1, E:1, V:1, A:1, L:1}
  /// getLetterCount('ROJA')  // {R:1, O:1, J:1, A:1}
  /// ```
  static Map<String, int> getLetterCount(String word) {
    final counts = <String, int>{};
    for (final ch in normalize(word).characters) {
      counts[ch] = (counts[ch] ?? 0) + 1;
    }
    return counts;
  }

  // ── Ana kontrol ───────────────────────────────────────────────

  /// [baseWord]'ü [newWord] ile çalıp çalamayacağını kontrol eder.
  ///
  /// Başarılı sonuç [StealResult.ok], başarısız [StealResult.fail] döner.
  StealResult canSteal(
    String baseWord,
    String newWord, {
    bool Function(String)? isValidWord,
    int currentSteals = 0,
  }) {
    final base = normalize(baseWord);
    final next = normalize(newWord);

    // ── 1. Minimum uzunluk ───────────────────────────────────
    if (base.characters.length < minLength) {
      return StealResult.fail(base, next,
          '"$base" çok kısa (min: $minLength, mevcut: ${base.characters.length})');
    }

    // ── 2. Çalma sayısı limiti ───────────────────────────────
    if (currentSteals >= maxSteals) {
      return StealResult.fail(base, next,
          '"$base" zaten $maxSteals kez çalındı');
    }

    // ── 3. Yeni kelime daha uzun olmalı ─────────────────────
    final baseLen = base.characters.length;
    final nextLen = next.characters.length;
    if (nextLen <= baseLen) {
      return StealResult.fail(base, next,
          '"$next" ($nextLen harf) "$base" ($baseLen harf) den uzun değil');
    }

    // ── 4. Harf içerme kontrolü (Map bazlı) ──────────────────
    //
    // [base]'deki her harf [next]'te en az aynı sayıda bulunmalı.
    final baseCounts = getLetterCount(base);
    final nextCounts = getLetterCount(next);

    for (final entry in baseCounts.entries) {
      final inNext = nextCounts[entry.key] ?? 0;
      if (inNext < entry.value) {
        return StealResult.fail(base, next,
            '"$next" içinde "${entry.key}" harfinden yetersiz '
            '(gerekli: ${entry.value}, mevcut: $inNext)');
      }
    }

    // ── 5. Sözlük kontrolü ───────────────────────────────────
    if (isValidWord != null && !isValidWord(next)) {
      return StealResult.fail(base, next, '"$next" sözlükte bulunamadı');
    }

    // ── Başarılı ─────────────────────────────────────────────
    final added   = nextLen - baseLen;
    final indices = newLetterIndices(base, next);

    return StealResult.ok(
      baseWord:   base,
      newWord:    next,
      addedCount: added,
      newIndices: indices,
    );
  }

  // ── İndeks hesaplama ──────────────────────────────────────────

  /// [next]'te [base]'e ek olarak gelen harflerin 0-tabanlı indekslerini döndürür.
  ///
  /// **Algoritma:** [base] harflerini greedy olarak [next] üzerinde eşleştir;
  /// eşleşemeyen konumlar "yeni harf".
  ///
  /// ```dart
  /// newLetterIndices('CAT', 'CATCH') // [3, 4]  → son C ve H yeni
  /// newLetterIndices('ROJ', 'ROJA')  // [3]      → A yeni
  /// newLetterIndices('ROJ', 'BROJA') // [0, 4]   → B ve A yeni
  /// ```
  static List<int> newLetterIndices(String base, String next) {
    final remaining = getLetterCount(normalize(base));
    final newIdx    = <int>[];
    int   i         = 0;

    for (final ch in normalize(next).characters) {
      if ((remaining[ch] ?? 0) > 0) {
        remaining[ch] = remaining[ch]! - 1; // base'den "kullanıldı"
      } else {
        newIdx.add(i);                       // bu harf yeni
      }
      i++;
    }
    return newIdx;
  }
}
