import 'package:kurdle_app/services/scoring_service.dart';

class GameTile {
  final String id;
  final String letter;
  final int points;

  GameTile({required this.id, required this.letter})
      : points = ScoringService.letterPointsCurrent(letter);

  @override
  String toString() => 'GameTile($letter/$points)';
}
