import 'package:kurdle_app/models/board_cell.dart';
import 'package:kurdle_app/models/word_board.dart';

class BoardLayoutService {
  static WordBoard createClassicLayout() {
    var board = WordBoard.empty();

    board = _applySymmetricBonus(
      board,
      {
        _BoardPoint(0, 0),
        _BoardPoint(0, 7),
        _BoardPoint(7, 0),
      },
      CellBonusType.tripleWord,
    );

    board = _applySymmetricBonus(
      board,
      {
        _BoardPoint(1, 1),
        _BoardPoint(2, 2),
        _BoardPoint(3, 3),
        _BoardPoint(4, 4),
        _BoardPoint(7, 7),
      },
      CellBonusType.doubleWord,
    );

    board = _applySymmetricBonus(
      board,
      {
        _BoardPoint(1, 5),
        _BoardPoint(5, 1),
        _BoardPoint(5, 5),
      },
      CellBonusType.tripleLetter,
    );

    board = _applySymmetricBonus(
      board,
      {
        _BoardPoint(0, 3),
        _BoardPoint(2, 6),
        _BoardPoint(3, 0),
        _BoardPoint(3, 7),
        _BoardPoint(6, 2),
        _BoardPoint(6, 6),
        _BoardPoint(7, 3),
      },
      CellBonusType.doubleLetter,
    );

    // Center starts the game.
    final center = board.cellAt(WordBoard.centerIndex, WordBoard.centerIndex);
    board = board.updateCell(center.copyWith(bonusType: CellBonusType.start));

    return board;
  }

  static WordBoard _applySymmetricBonus(
    WordBoard board,
    Set<_BoardPoint> anchorPoints,
    CellBonusType bonusType,
  ) {
    var next = board;

    for (final point in anchorPoints) {
      final row = point.row;
      final column = point.column;
      final mirroredPositions = _mirroredPositions(row, column);

      for (final mirrored in mirroredPositions) {
        final cell = next.cellAt(mirrored.row, mirrored.column);
        next = next.updateCell(cell.copyWith(bonusType: bonusType));
      }
    }

    return next;
  }

  static Set<_BoardPoint> _mirroredPositions(int row, int column) {
    const max = WordBoard.size - 1;

    return {
      _BoardPoint(row, column),
      _BoardPoint(row, max - column),
      _BoardPoint(max - row, column),
      _BoardPoint(max - row, max - column),
      _BoardPoint(column, row),
      _BoardPoint(column, max - row),
      _BoardPoint(max - column, row),
      _BoardPoint(max - column, max - row),
    };
  }
}

class _BoardPoint {
  final int row;
  final int column;

  const _BoardPoint(this.row, this.column);

  @override
  bool operator ==(Object other) {
    return other is _BoardPoint && row == other.row && column == other.column;
  }

  @override
  int get hashCode => Object.hash(row, column);
}
