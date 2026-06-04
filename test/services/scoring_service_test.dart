import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/services/scoring_service.dart';

// Skorlama motoru adalet-kritik çekirdek — bu testler regresyona karşı kilit.
void main() {
  group('ScoringService.attemptMultiplier', () {
    test('1. denemede ×6, her denemede azalır, 6+ sabit ×1', () {
      expect(ScoringService.attemptMultiplier(0), 6);
      expect(ScoringService.attemptMultiplier(1), 5);
      expect(ScoringService.attemptMultiplier(2), 4);
      expect(ScoringService.attemptMultiplier(3), 3);
      expect(ScoringService.attemptMultiplier(4), 2);
      expect(ScoringService.attemptMultiplier(5), 1);
      expect(ScoringService.attemptMultiplier(6), 1);
      expect(ScoringService.attemptMultiplier(99), 1);
    });
  });

  group('kurdishLetterPoints tablosu', () {
    test('sık harfler 1 puan', () {
      for (final c in ['A', 'E', 'I', 'N', 'R', 'T']) {
        expect(kurdishLetterPoints[c], 1, reason: '$c = 1 olmalı');
      }
    });
    test('nadir Q ve X 8 puan', () {
      expect(kurdishLetterPoints['Q'], 8);
      expect(kurdishLetterPoints['X'], 8);
    });
    test('Kurmancî aksanlı sesliler Ê/Î/Û 5 puan', () {
      expect(kurdishLetterPoints['Ê'], 5);
      expect(kurdishLetterPoints['Î'], 5);
      expect(kurdishLetterPoints['Û'], 5);
    });
  });

  group('ScoringService instance', () {
    const svc = ScoringService(kurdishLetterPoints);

    test('letterPoints büyük/küçük harf duyarsız, bilinmeyen → 1', () {
      expect(svc.letterPoints('a'), 1);
      expect(svc.letterPoints('Q'), 8);
      expect(svc.letterPoints('q'), 8);
      expect(svc.letterPoints('@'), 1);
    });

    test('wordScore harf puanlarının toplamı (Kurmancî dahil)', () {
      expect(svc.wordScore('AN'), 2); // 1+1
      expect(svc.wordScore('qax'), 17); // 8+1+8, küçük harf de aynı
      expect(svc.wordScore('ÊR'), 6); // 5+1
      expect(svc.wordScore(''), 0); // boş kelime 0
    });
  });

  group('ScoringService.calculateScore', () {
    test('temel skoru deneme çarpanıyla ölçekler (puan tablosundan bağımsız oran)', () {
      final first = ScoringService.calculateScore('AN', 0);
      final last = ScoringService.calculateScore('AN', 5);
      expect(last, greaterThan(0));
      // 1. deneme = ×6, 6. deneme = ×1 → ilk, sonuncunun 6 katı olmalı.
      expect(first, 6 * last);
    });
  });
}
