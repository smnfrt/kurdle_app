import 'package:flutter/material.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/services/scoring_service.dart';

class Keyboard extends StatelessWidget {
  final List<List<Letter>> _keys;
  final ValueSetter<String> _onKeyPressed;
  final Settings _settings;

  const Keyboard(this._keys, this._settings, this._onKeyPressed, {super.key});

  Color _toColor(GameColor color) {
    switch (color) {
      case GameColor.correct:
        return _settings.isHighContrast ? Colors.orange : Colors.green;
      case GameColor.present:
        return _settings.isHighContrast ? Colors.blue : const Color.fromARGB(255, 207, 187, 98);
      case GameColor.absent:
        return const Color.fromARGB(255, 90, 87, 87);
      case GameColor.tbd:
        return const Color.fromARGB(255, 151, 151, 151);
    }
  }

  Widget _buildCell(Letter letter) {
    final isSingleLetter = letter.value.length == 1;
    final pts = isSingleLetter ? ScoringService.letterPointsCurrent(letter.value) : null;

    return Semantics(
      label: letter.semanticsLabel,
      keyboardKey: true,
      child: GestureDetector(
        onTap: () {
          _onKeyPressed.call(letter.value);
        },
        child: SizedBox(
          width: letter.value.length > 1 ? 60 : 40,
          height: 58,
          child: Padding(
            padding: const EdgeInsets.all(2.0),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  border: Border.all(
                    width: 1,
                    color: Colors.grey.shade800,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(4)),
                  color: _toColor(letter.color)),
              child: Stack(
                children: [
                  // Merkezdeki harf/ENTER/⌫
                  Center(
                    child: ExcludeSemantics(
                      excluding: true,
                      child: Text(
                        letter.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: letter.value.length > 1 ? 10 : 18,
                            color: letter.color != GameColor.tbd ? Colors.white : null),
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
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: letter.color != GameColor.tbd
                              ? Colors.white70
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildKeys() {
    final rows = <Widget>[];

    for (var x = 0; x < _keys.length; x++) {
      final cells = <Widget>[];
      for (var y = 0; y < _keys[x].length; y++) {
        cells.add(_buildCell(_keys[x][y]));
      }
      rows.add(FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: cells),
      ));
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 400, height: 200, child: Column(children: _buildKeys()));
  }
}
