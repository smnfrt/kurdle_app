import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/services/tile_bag_service.dart';

void main() {
  group('TileBagService - kuruluş (constructor)', () {
    test('dağılımdaki toplam taş sayısı kadar taş üretir', () {
      final bag = TileBagService({'A': 3, 'B': 2, 'C': 1});
      // Toplam = 3 + 2 + 1 = 6
      expect(bag.remaining, 6);
    });

    test('boş dağılım ile sıfır taşlı torba kurar', () {
      final bag = TileBagService({});
      expect(bag.remaining, 0);
      expect(bag.isEmpty, isTrue);
    });

    test('count 0 olan harf hiç taş eklemez', () {
      final bag = TileBagService({'A': 0, 'B': 4});
      expect(bag.remaining, 4);
    });

    test('üretilen taşların harfleri yalnızca dağılımdaki harflerden oluşur '
        've harf başına doğru sayıda', () {
      final bag = TileBagService({'A': 2, 'B': 3});
      final drawn = bag.drawMany(5);
      final aCount = drawn.where((t) => t.letter == 'A').length;
      final bCount = drawn.where((t) => t.letter == 'B').length;
      expect(aCount, 2);
      expect(bCount, 3);
    });

    test('her taşın id\'si benzersizdir (tile_0..tile_n)', () {
      final bag = TileBagService({'A': 5});
      final drawn = bag.drawMany(5);
      final ids = drawn.map((t) => t.id).toSet();
      expect(ids.length, 5, reason: 'tüm id\'ler benzersiz olmalı');
      // id prefix kontrolü
      for (final t in drawn) {
        expect(t.id, startsWith('tile_'));
      }
    });
  });

  group('TileBagService - remaining / isEmpty', () {
    test('yeni torbada isEmpty doğru çalışır', () {
      final dolu = TileBagService({'A': 1});
      final bos = TileBagService({});
      expect(dolu.isEmpty, isFalse);
      expect(bos.isEmpty, isTrue);
    });

    test('drawOne sonrası remaining bir azalır', () {
      final bag = TileBagService({'A': 3});
      expect(bag.remaining, 3);
      bag.drawOne();
      expect(bag.remaining, 2);
      bag.drawOne();
      expect(bag.remaining, 1);
    });
  });

  group('TileBagService - drawOne (tek taş çekme)', () {
    test('dolu torbadan non-null GameTile döner', () {
      final bag = TileBagService({'A': 1});
      final tile = bag.drawOne();
      expect(tile, isNotNull);
      expect(tile, isA<GameTile>());
      expect(tile!.letter, 'A');
    });

    test('boş torbadan null döner ve remaining 0 kalır', () {
      final bag = TileBagService({});
      final tile = bag.drawOne();
      expect(tile, isNull);
      expect(bag.remaining, 0);
    });

    test('torbayı tek tek tamamen boşaltır, son çekimden sonra null gelir', () {
      final bag = TileBagService({'A': 2});
      expect(bag.drawOne(), isNotNull);
      expect(bag.drawOne(), isNotNull);
      expect(bag.remaining, 0);
      expect(bag.drawOne(), isNull);
      expect(bag.isEmpty, isTrue);
    });
  });

  group('TileBagService - drawMany (çoklu taş çekme)', () {
    test('istenen sayıda taş çeker ve remaining buna göre düşer', () {
      final bag = TileBagService({'A': 10});
      final drawn = bag.drawMany(4);
      expect(drawn.length, 4);
      expect(bag.remaining, 6);
    });

    test('kalan taştan fazlası istenirse yalnızca kalanı döner (taşma yok)', () {
      final bag = TileBagService({'A': 3});
      final drawn = bag.drawMany(10);
      expect(drawn.length, 3, reason: 'sadece kalan 3 taş çekilebilir');
      expect(bag.remaining, 0);
      expect(bag.isEmpty, isTrue);
    });

    test('count 0 verilirse boş liste döner ve torba değişmez', () {
      final bag = TileBagService({'A': 5});
      final drawn = bag.drawMany(0);
      expect(drawn, isEmpty);
      expect(bag.remaining, 5);
    });

    test('negatif count verilirse boş liste döner ve torba değişmez', () {
      final bag = TileBagService({'A': 5});
      final drawn = bag.drawMany(-3);
      expect(drawn, isEmpty);
      expect(bag.remaining, 5);
    });

    test('boş torbadan drawMany boş liste döner', () {
      final bag = TileBagService({});
      final drawn = bag.drawMany(5);
      expect(drawn, isEmpty);
      expect(bag.remaining, 0);
    });

    test('tam torba boyutu kadar çekince hepsi gelir ve torba boşalır', () {
      final bag = TileBagService({'A': 2, 'B': 2});
      final drawn = bag.drawMany(4);
      expect(drawn.length, 4);
      expect(bag.isEmpty, isTrue);
    });
  });

  group('TileBagService - returnTiles (taş geri koyma)', () {
    test('geri konan taş sayısı remaining\'e eklenir', () {
      final bag = TileBagService({'A': 5});
      final drawn = bag.drawMany(3);
      expect(bag.remaining, 2);
      bag.returnTiles(drawn);
      expect(bag.remaining, 5);
    });

    test('boş listeyi geri koymak remaining\'i değiştirmez', () {
      final bag = TileBagService({'A': 4});
      bag.returnTiles([]);
      expect(bag.remaining, 4);
    });

    test('boşalmış torbaya geri koyunca tekrar çekilebilir hale gelir', () {
      final bag = TileBagService({'A': 2});
      final drawn = bag.drawMany(2);
      expect(bag.isEmpty, isTrue);
      bag.returnTiles(drawn);
      expect(bag.isEmpty, isFalse);
      expect(bag.remaining, 2);
    });

    test('dışarıdan üretilen taşlar geri konabilir ve sayıyı artırır', () {
      final bag = TileBagService({'A': 1});
      final ekstra = [
        GameTile(id: 'x1', letter: 'B'),
        GameTile(id: 'x2', letter: 'C'),
      ];
      bag.returnTiles(ekstra);
      expect(bag.remaining, 3);
    });

    test('çek-geri koy-çek döngüsünde taş kaybı/çoğalması olmaz', () {
      final bag = TileBagService({'A': 3, 'B': 3});
      final drawn = bag.drawMany(6);
      expect(bag.remaining, 0);
      bag.returnTiles(drawn);
      expect(bag.remaining, 6);
      final yeniden = bag.drawMany(6);
      expect(yeniden.length, 6);
      expect(bag.remaining, 0);
    });
  });
}
