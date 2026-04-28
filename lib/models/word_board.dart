import 'package:kurdle_app/models/board_cell.dart';

class WordBoard {
  static const int size = 15;
  static const int totalCells = size * size;
  static const int centerIndex = 7;

  final List<BoardCell> cells;

  const WordBoard(this.cells);

  factory WordBoard.empty() {
    final generated = <BoardCell>[];
    for (var row = 0; row < size; row++) {
      for (var column = 0; column < size; column++) {
        generated.add(BoardCell(row: row, column: column));
      }
    }
    return WordBoard(generated);
  }

  BoardCell cellAt(int row, int column) => cells[row * size + column];

  WordBoard updateCell(BoardCell updatedCell) {
    final next = [...cells];
    next[updatedCell.row * size + updatedCell.column] = updatedCell;
    return WordBoard(next);
  }

  WordBoard placeLetter(int row, int column, String letter) {
    final cell = cellAt(row, column);
    return updateCell(
        cell.copyWith(letter: letter.trim().toUpperCase()));
  }

  WordBoard placePending(int row, int column, String letter, String tileId) {
    final cell = cellAt(row, column);
    return updateCell(cell.copyWith(
      letter: letter.trim().toUpperCase(),
      isPending: true,
      tileId: tileId,
    ));
  }

  WordBoard clearLetter(int row, int column) {
    return updateCell(cellAt(row, column).cleared());
  }

  WordBoard commitPending() {
    final next = cells.map((c) {
      if (c.isPending) return c.copyWith(isPending: false, tileId: null);
      return c;
    }).toList();
    return WordBoard(next);
  }

  WordBoard clearPending() {
    final next = cells.map((c) {
      if (c.isPending) return c.cleared();
      return c;
    }).toList();
    return WordBoard(next);
  }

  List<BoardCell> get pendingCells =>
      cells.where((c) => c.isPending).toList();
}
