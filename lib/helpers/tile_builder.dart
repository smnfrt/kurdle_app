import 'package:flutter/material.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/services/scoring_service.dart';

class TileBuilder {

  static Color _toColor(GameColor color, Settings settings) {
    switch (color) {
      case GameColor.correct:
        return settings.isHighContrast ? Colors.orange : Colors.green;
      case GameColor.present:
        return settings.isHighContrast ? Colors.blue : const Color.fromARGB(255, 207, 187, 98);
      case GameColor.absent:
        return const Color.fromARGB(255, 90, 87, 87);
      case GameColor.tbd:
        return Colors.transparent;
    }
  }

  static Widget build(Letter letter, Settings settings) {
    final pts = letter.value.isNotEmpty && letter.value.length == 1
        ? ScoringService.letterPointsCurrent(letter.value)
        : null;

    return Padding(
      key: ValueKey(letter.color == GameColor.tbd),
      padding: const EdgeInsets.all(2.0),
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
              border: Border.all(
                width: 2,
                color: Colors.grey.shade800,
              ),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              color: _toColor(letter.color, settings)),
          child: Stack(
            children: [
              // Merkezdeki harf
              Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Semantics(
                    label: letter.semanticsLabel,
                    child: ExcludeSemantics(
                      excluding: true,
                      child: Text(
                        letter.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: (letter.color != GameColor.tbd) ? Colors.white : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Sağ alt köşe: Scrabble puan değeri
              if (pts != null)
                Positioned(
                  right: 3,
                  bottom: 2,
                  child: Text(
                    '$pts',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: letter.color != GameColor.tbd
                          ? Colors.white70
                          : Colors.grey.shade500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
