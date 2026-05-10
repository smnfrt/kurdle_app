class PlacedWordRecord {
  final String word;
  final bool isHorizontal;
  final int fixedLine;     // H → satır, V → sütun
  final int startPos;      // H → başlangıç sütun, V → başlangıç satır
  final int endPos;        // H → bitiş sütun,    V → bitiş satır
  final int originalScore;
  final int originalOwner; // 0=oyuncu, 1=AI
  int owner;               // geçerli sahip
  final int turnPlaced;
  int enhanceCount;
  int? lastEnhancedBy;     // son geliştiren: 0=oyuncu, 1=AI

  PlacedWordRecord({
    required this.word,
    required this.isHorizontal,
    required this.fixedLine,
    required this.startPos,
    required this.endPos,
    required this.originalScore,
    required this.originalOwner,
    required this.owner,
    required this.turnPlaced,
    this.enhanceCount = 0,
    this.lastEnhancedBy,
  });

  /// Bu kelimenin kapsamı yeni kelimenin kapsamı tarafından genişletilip
  /// genişletilmediğini kontrol eder (yeni kelime daha uzun ve tam içeriyor).
  bool isExtendedBy({
    required bool horizontal,
    required int line,
    required int newStart,
    required int newEnd,
  }) {
    if (isHorizontal != horizontal) return false;
    if (fixedLine != line) return false;
    return newStart <= startPos &&
        endPos <= newEnd &&
        (newStart < startPos || endPos < newEnd);
  }
}
