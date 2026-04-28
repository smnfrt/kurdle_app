import 'package:flutter/material.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/board_layout_service.dart';

class BoardController extends ChangeNotifier {
  WordBoard _board;

  BoardController({WordBoard? initialBoard})
      : _board = initialBoard ?? BoardLayoutService.createClassicLayout();

  WordBoard get board => _board;

  void resetBoard() {
    _board = BoardLayoutService.createClassicLayout();
    notifyListeners();
  }

  void placeLetter({
    required int row,
    required int column,
    required String letter,
  }) {
    _board = _board.placeLetter(row, column, letter);
    notifyListeners();
  }

  void clearCell({
    required int row,
    required int column,
  }) {
    _board = _board.clearLetter(row, column);
    notifyListeners();
  }
}
