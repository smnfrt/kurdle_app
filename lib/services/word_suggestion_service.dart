// word_suggestion_service.dart
//
// Kürmancî kelime oyunu için Levenshtein tabanlı öneri sistemi.
// Diacritic normalizasyonu, first-char indeksi ve uzunluk filtresi
// sayesinde büyük sözlüklerde bile hızlı çalışır.
//
// Kullanım:
//   final svc = WordSuggestionService(myWordList);
//   print(svc.isValidWord('ŞIVAN'));      // true/false
//   print(svc.suggestWord('SIVAN'));      // 'ŞIVAN'

import 'package:flutter/material.dart';
import 'package:kurdle_app/models/word_suggestion.dart';
import 'package:kurdle_app/services/app_locale.dart';

// ─── Servis ──────────────────────────────────────────────────────────────────

class WordSuggestionService {
  // Normalize edilmiş ilk harfe göre gruplanmış sözlük.
  // Anahtar: büyük harfe çevrilmiş + aksansız ilk karakter (ör. 'Ê' → 'E')
  // Değer: orijinal (aksanlı) kelimeler listesi
  final Map<String, List<String>> _index;

  // O(1) geçerlilik kontrolü için Set
  final Set<String> _words;

  WordSuggestionService(Iterable<String> words)
      : _words = words
            .map((w) => w.trim().toUpperCase())
            .where((w) => w.isNotEmpty)
            .toSet(),
        _index = _buildIndex(
          words.map((w) => w.trim().toUpperCase()).where((w) => w.isNotEmpty),
        );

  // ── İndeks kurma ────────────────────────────────────────────────────────────

  /// Normalize edilmiş ilk harf → orijinal kelimeler şeklinde indeks oluşturur.
  static Map<String, List<String>> _buildIndex(Iterable<String> words) {
    final idx = <String, List<String>>{};
    for (final w in words) {
      // Küçük harf kürtçe karakterleri de yakala (ê, î, û, ş, ç …)
      final key = normalize(w.characters.first);
      (idx[key] ??= []).add(w);
    }
    return idx;
  }

  // ── Temel fonksiyonlar ───────────────────────────────────────────────────────

  /// Kürtçe/Türkçe aksan karakterlerini ASCII karşılıklarına çevirir.
  /// Sadece KARŞILAŞTIRMA için kullanılır; döndürülen öneriler orijinal
  /// aksanlı halleriyle gösterilir (ör. 'ŞIVAN' değil 'SIVAN').
  static String normalize(String word) {
    return word.toUpperCase().characters.map((ch) {
      switch (ch) {
        case 'Ê': return 'E';
        case 'Î': return 'I';  // büyük î (Kürmancî'de farklı ses)
        case 'Û': return 'U';
        case 'Ş': return 'S';
        case 'Ç': return 'C';
        case 'Ğ': return 'G';
        case 'Ö': return 'O';
        case 'Ü': return 'U';
        case 'İ': return 'I';  // noktalı büyük I (Türkçe)
        default:  return ch;
      }
    }).join();
  }

  /// Kelime uzunluğuna göre izin verilen maksimum hata sayısı.
  ///   3–5 harf  → 1 hata
  ///   6–8 harf  → 2 hata
  ///   9+  harf  → 2 hata
  static int getThreshold(int length) {
    if (length <= 5) return 1;
    return 2; // 6-8 ve 9+
  }

  /// Kelimeyi sözlükte arar (büyük/küçük harf ve boşluk farkı gözetmez).
  bool isValidWord(String word) => _words.contains(word.trim().toUpperCase());

  /// Unicode grapheme cluster'larını dikkate alan Levenshtein mesafesi.
  /// (Ê, Î, Û gibi çok-baytlı karakterler tek karakter sayılır.)
  static int levenshtein(String a, String b) {
    final ac = a.characters.toList();
    final bc = b.characters.toList();
    final m = ac.length;
    final n = bc.length;

    // Bellek optimizasyonu: sadece 2 satır tut
    var prev = List.generate(n + 1, (j) => j);
    var curr = List.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      for (var j = 1; j <= n; j++) {
        if (ac[i - 1] == bc[j - 1]) {
          curr[j] = prev[j - 1];
        } else {
          curr[j] = 1 +
              _min3(
                prev[j],      // silme
                curr[j - 1],  // ekleme
                prev[j - 1],  // değiştirme
              );
        }
      }
      final tmp = prev; prev = curr; curr = tmp;
    }
    return prev[n];
  }

  static int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);

  /// Sözlükte bulunmayan bir kelime için en yakın öneriyi döndürür.
  /// Zaten geçerliyse null döner. Threshold aşılırsa null döner.
  ///
  /// Performans filtreleri (sırasıyla):
  ///   1. İlk karakter eşleşmesi (normalize edilmiş)
  ///   2. Uzunluk farkı ≤ threshold
  ///   3. Levenshtein mesafesi ≤ threshold
  String? suggestWord(String word) {
    final upper = word.trim().toUpperCase();
    if (isValidWord(upper)) return null; // zaten geçerli

    final norm    = normalize(upper);
    final normLen = norm.characters.length;
    final thresh  = getThreshold(normLen);

    // Filtre 1: normalize edilmiş ilk harf
    final firstChar  = norm.characters.first;
    final candidates = _index[firstChar];
    if (candidates == null || candidates.isEmpty) return null;

    String? best;
    var bestDist = thresh + 1; // başlangıç: threshold dışında

    for (final candidate in candidates) {
      final normCand = normalize(candidate);
      final candLen  = normCand.characters.length;

      // Filtre 2: uzunluk farkı
      if ((candLen - normLen).abs() > thresh) continue;

      // Filtre 3: Levenshtein
      final d = levenshtein(norm, normCand);
      if (d < bestDist) {
        bestDist = d;
        best     = candidate; // orijinal aksanlı kelimeyi sakla
        if (d == 0) break;    // normalize mesafe 0 → mükemmel eşleşme
      }
    }

    return best; // null ise öneri yok
  }

  /// [suggestWord]'ü sarmalar; model nesnesi döndürür.
  WordSuggestion? suggest(String word) {
    final s = suggestWord(word);
    if (s == null) return null;
    return WordSuggestion(original: word.trim().toUpperCase(), suggested: s);
  }
}

// ─── UI: öneri popup'u ───────────────────────────────────────────────────────

/// Geçersiz kelime girildiğinde "X demek istedin mi?" dialog'u gösterir.
///
/// Kullanım (herhangi bir widget içinden):
///   final accepted = await WordSuggestionDialog.show(
///     context,
///     suggestion: WordSuggestion(original: 'SIVAN', suggested: 'ŞIVAN'),
///   );
///   if (accepted == true) { /* önerilen kelimeyi gönder */ }
class WordSuggestionDialog {
  WordSuggestionDialog._();

  /// [true]  → kullanıcı "Evet" seçti (öneriyi kabul et)
  /// [false] → kullanıcı "Hayır" seçti
  /// [null]  → dialog dışına tıklandı / kapandı
  static Future<bool?> show(
    BuildContext context, {
    required WordSuggestion suggestion,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuggestionSheet(suggestion: suggestion),
    );
  }
}

class _SuggestionSheet extends StatelessWidget {
  final WordSuggestion suggestion;
  const _SuggestionSheet({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2A3A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Çekme çubuğu
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // İkon
          const Icon(Icons.lightbulb_rounded,
              color: Color(0xFFFFB74D), size: 36),
          const SizedBox(height: 12),

          // Soru
          Text(
            L.didYouMean(suggestion.suggested),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),

          // Girilen yanlış kelime
          Text(
            '"${suggestion.original}"',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 13,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.white38,
            ),
          ),
          const SizedBox(height: 28),

          // Butonlar
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white54,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(L.suggestionReject,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB74D),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(L.suggestionAccept,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
