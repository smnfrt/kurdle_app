enum CellBonusType {
  none,
  doubleLetter,
  tripleLetter,
  doubleWord,
  tripleWord,
  start,
}

class BoardCell {
  final int row;
  final int column;
  final CellBonusType bonusType;
  final String letter;
  final bool isPending;
  final String? tileId;

  const BoardCell({
    required this.row,
    required this.column,
    this.bonusType = CellBonusType.none,
    this.letter = '',
    this.isPending = false,
    this.tileId,
  });

  bool get hasLetter => letter.isNotEmpty;
  bool get isLocked => hasLetter && !isPending;

  int get letterMultiplier {
    switch (bonusType) {
      case CellBonusType.doubleLetter:
        return 2;
      case CellBonusType.tripleLetter:
        return 3;
      default:
        return 1;
    }
  }

  int get wordMultiplier {
    switch (bonusType) {
      case CellBonusType.doubleWord:
      case CellBonusType.start:
        return 2;
      case CellBonusType.tripleWord:
        return 3;
      default:
        return 1;
    }
  }

  BoardCell copyWith({
    CellBonusType? bonusType,
    String? letter,
    bool? isPending,
    String? tileId,
  }) {
    return BoardCell(
      row: row,
      column: column,
      bonusType: bonusType ?? this.bonusType,
      letter: letter ?? this.letter,
      isPending: isPending ?? this.isPending,
      tileId: tileId ?? this.tileId,
    );
  }

  BoardCell cleared() =>
      BoardCell(row: row, column: column, bonusType: bonusType);
}
