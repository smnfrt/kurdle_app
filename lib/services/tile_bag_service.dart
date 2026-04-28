import 'dart:math';
import 'package:kurdle_app/models/game_tile.dart';

class TileBagService {
  final List<GameTile> _bag = [];
  int _nextId = 0;
  final _rng = Random();

  TileBagService(Map<String, int> distribution) {
    distribution.forEach((letter, count) {
      for (var i = 0; i < count; i++) {
        _bag.add(GameTile(id: 'tile_${_nextId++}', letter: letter));
      }
    });
    _bag.shuffle(_rng);
  }

  int get remaining => _bag.length;
  bool get isEmpty => _bag.isEmpty;

  GameTile? drawOne() => _bag.isNotEmpty ? _bag.removeLast() : null;

  List<GameTile> drawMany(int count) {
    final drawn = <GameTile>[];
    for (var i = 0; i < count && _bag.isNotEmpty; i++) {
      drawn.add(_bag.removeLast());
    }
    return drawn;
  }

  void returnTiles(List<GameTile> tiles) {
    _bag.addAll(tiles);
    _bag.shuffle(_rng);
  }
}
