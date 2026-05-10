import 'package:flutter/material.dart';
import 'package:kurdle_app/models/board_cell.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/scoring_service.dart';
import 'package:kurdle_app/services/haptic_service.dart';

// ── Dark-premium renk paleti ────────────────────────────────────
const _kBoardFrame   = Color(0xFF080F18);
const _kBoardBg      = Color(0xFF10192A);
const _kCellNormal   = Color(0xFF1C2E42);
const _kCellBorder   = Color(0xFF243650);
const _kGridLine     = Color(0xFF1E3050);

// Bonus gradyanlar
const _kTWa = Color(0xFF6B1212); const _kTWb = Color(0xFF9B1C1C);
const _kDWa = Color(0xFF7A3800); const _kDWb = Color(0xFFB85600);
const _kTLa = Color(0xFF122C6B); const _kTLb = Color(0xFF1A44A0);
const _kDLa = Color(0xFF0B3C3C); const _kTLb2 = Color(0xFF115A5A);
const _kCTa = Color(0xFF5A3D00); const _kCTb = Color(0xFFAA7800);

// Taş renkleri
const _kTilePendA = Color(0xFFFFF8E1); const _kTilePendB = Color(0xFFFFCC44);
const _kTileLocA  = Color(0xFFD4B896); const _kTileLocB  = Color(0xFF9A7040);
const _kTileBorder   = Color(0xFFB8860B);
const _kTilePendBord = Color(0xFFFFA000);
const _kTileText     = Color(0xFF22100A);
const _kTilePoints   = Color(0xFF6B3A1A);
const _kPrimary      = Color(0xFF4CAF50);

const _letterPts = kurdishLetterPoints;

class ScrabbleBoardWidget extends StatefulWidget {
  final WordBoard board;
  final void Function(int row, int col, GameTile tile)? onTileDrop;
  final void Function(int row, int col)? onCellTap;
  final void Function(int row, int col)? onEmptyCellTap;
  final double spacing;
  /// Geliştirilen kelimenin hücrelerini altın rengiyle vurgular (ör. {'5:3','5:4'})
  final Set<String> highlightedCells;
  /// Çalınan kelimede yeni eklenen harflerin hücreleri — teal rengiyle vurgulanır
  final Set<String> stolenNewCells;

  const ScrabbleBoardWidget({
    Key? key,
    required this.board,
    this.onTileDrop,
    this.onCellTap,
    this.onEmptyCellTap,
    this.spacing = 1.4,
    this.highlightedCells = const {},
    this.stolenNewCells   = const {},
  }) : super(key: key);

  @override
  State<ScrabbleBoardWidget> createState() => _ScrabbleBoardWidgetState();
}

class _ScrabbleBoardWidgetState extends State<ScrabbleBoardWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.maxWidth < constraints.maxHeight
          ? constraints.maxWidth
          : constraints.maxHeight;

      return RepaintBoundary(
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: _kBoardFrame,
            borderRadius: BorderRadius.all(Radius.circular(14)),
            boxShadow: [
              BoxShadow(color: Color(0xAA000000), blurRadius: 24, offset: Offset(0, 10)),
              BoxShadow(color: Color(0x30000000), blurRadius: 6,  offset: Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: const BoxDecoration(
              color: _kBoardBg,
              borderRadius: BorderRadius.all(Radius.circular(10)),
              border: Border.fromBorderSide(BorderSide(color: _kGridLine, width: 1)),
            ),
            padding: const EdgeInsets.all(3),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: WordBoard.totalCells,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: WordBoard.size,
                mainAxisSpacing: widget.spacing,
                crossAxisSpacing: widget.spacing,
              ),
              itemBuilder: (context, index) {
                final row  = index ~/ WordBoard.size;
                final col  = index %  WordBoard.size;
                final cell = widget.board.cellAt(row, col);
                final isHighlighted = widget.highlightedCells.contains('$row:$col');
                final isNewStolen   = widget.stolenNewCells.contains('$row:$col');
                return _CellView(
                  cell: cell,
                  isHighlighted: isHighlighted,
                  isNewStolen: isNewStolen,
                  ambient: _ambient,
                  onDrop:     widget.onTileDrop != null ? (t) => widget.onTileDrop!(row, col, t) : null,
                  onTap:      widget.onCellTap != null ? () => widget.onCellTap!(row, col) : null,
                  onEmptyTap: widget.onEmptyCellTap != null ? () => widget.onEmptyCellTap!(row, col) : null,
                );
              },
            ),
          ),
        ),
      );
    });
  }
}

// ── Hücre görünümü ───────────────────────────────────────────────

class _CellView extends StatelessWidget {
  final BoardCell cell;
  final bool isHighlighted;
  final bool isNewStolen;
  final Animation<double>? ambient;
  final void Function(GameTile)? onDrop;
  final VoidCallback? onTap;
  final VoidCallback? onEmptyTap;

  const _CellView({
    required this.cell,
    this.isHighlighted = false,
    this.isNewStolen   = false,
    this.ambient,
    this.onDrop,
    this.onTap,
    this.onEmptyTap,
  });

  Gradient? _bonusGradient() {
    switch (cell.bonusType) {
      case CellBonusType.tripleWord:
        return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kTWa, _kTWb]);
      case CellBonusType.doubleWord:
        return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kDWa, _kDWb]);
      case CellBonusType.tripleLetter:
        return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kTLa, _kTLb]);
      case CellBonusType.doubleLetter:
        return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kDLa, _kTLb2]);
      case CellBonusType.start:
        return const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [_kCTa, _kCTb]);
      case CellBonusType.none:
        return null;
    }
  }

  Color? _bonusGlow() {
    switch (cell.bonusType) {
      case CellBonusType.tripleWord:    return const Color(0xFF9B1C1C);
      case CellBonusType.doubleWord:    return const Color(0xFFB85600);
      case CellBonusType.tripleLetter:  return const Color(0xFF1A44A0);
      case CellBonusType.doubleLetter:  return const Color(0xFF115A5A);
      case CellBonusType.start:         return const Color(0xFFAA7800);
      case CellBonusType.none:          return null;
    }
  }

  String _bonusLabel() {
    switch (cell.bonusType) {
      case CellBonusType.tripleWord:   return '3W';
      case CellBonusType.doubleWord:   return '2W';
      case CellBonusType.tripleLetter: return '3L';
      case CellBonusType.doubleLetter: return '2L';
      case CellBonusType.start:        return '★';
      case CellBonusType.none:         return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLetter  = cell.hasLetter;
    final isPending = cell.isPending;

    // ── Taş içeriği ─────────────────────────────────────────────
    if (isLetter) {
      final pts = _letterPts[cell.letter] ?? 1;

      // Kilitli taş: sabit Container (animasyon yok → daha hızlı)
      Widget tileWidget = RepaintBoundary(
        child: isPending
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_kTilePendA, _kTilePendB],
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                  border: Border.all(color: _kTilePendBord, width: 1.4),
                  boxShadow: const [
                    BoxShadow(color: Color(0x8DFFA000), blurRadius: 5, offset: Offset(0, 2)),
                    BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(1, 2)),
                  ],
                ),
                child: _TileContent(letter: cell.letter, pts: pts, isPending: true),
              )
            : Container(
                decoration: BoxDecoration(
                  gradient: isHighlighted
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
                        )
                      : isNewStolen
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF004D40), Color(0xFF00695C)],
                            )
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_kTileLocA, _kTileLocB],
                            ),
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                  border: Border.all(
                    color: isHighlighted
                        ? const Color(0xFFFFD700)
                        : isNewStolen
                            ? const Color(0xFF1DE9B6)
                            : _kTileBorder,
                    width: isHighlighted ? 1.8 : isNewStolen ? 1.6 : 1.0,
                  ),
                  boxShadow: isHighlighted
                      ? const [
                          BoxShadow(color: Color(0xCCFFD700), blurRadius: 8, spreadRadius: 1),
                          BoxShadow(color: Color(0x73000000), blurRadius: 2, offset: Offset(1, 2)),
                        ]
                      : isNewStolen
                          ? const [
                              BoxShadow(color: Color(0x991DE9B6), blurRadius: 8, spreadRadius: 1),
                              BoxShadow(color: Color(0x73000000), blurRadius: 2, offset: Offset(1, 2)),
                            ]
                          : const [
                              BoxShadow(color: Color(0x73000000), blurRadius: 2, offset: Offset(1, 2)),
                            ],
                ),
                child: _TileContent(letter: cell.letter, pts: pts, isPending: false),
              ),
      );

      // Pending taş → sürüklenebilir + baskı animasyonu
      if (isPending && onTap != null) {
        final tile = GameTile(id: cell.tileId!, letter: cell.letter);
        tileWidget = Draggable<GameTile>(
          data: tile,
          onDragStarted: onTap,
          feedback: RepaintBoundary(child: _DragFeedback(letter: cell.letter, points: pts)),
          childWhenDragging: Opacity(opacity: 0.15, child: tileWidget),
          child: _PressScaleWrap(onTap: onTap, child: tileWidget),
        );
      }

      // Pop animasyonu — sadece yeni eklenen pending taşlar için
      if (isPending) {
        return TweenAnimationBuilder<double>(
          key: ValueKey('pop-${cell.tileId}'),
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 320),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child!),
          child: tileWidget,
        );
      }

      return tileWidget;
    }

    // ── Boş hücre ────────────────────────────────────────────────
    final grad     = _bonusGradient();
    final glow     = _bonusGlow();
    final label    = _bonusLabel();
    final hasBonus = grad != null;

    // Sabit boş hücre (DragTarget yoksa) — bonus hücrelerde yumuşak ambient nefes alma
    Widget emptyCell = RepaintBoundary(
      child: hasBonus && glow != null && ambient != null
          ? AnimatedBuilder(
              animation: ambient!,
              builder: (_, __) {
                // 0.30 → 0.55 arası yavaş pulse
                final t = ambient!.value;
                final glowAlpha = 0.30 + 0.25 * t;
                final blur = 3.5 + 2.5 * t;
                final isStar = cell.bonusType == CellBonusType.start;
                return Container(
                  decoration: BoxDecoration(
                    gradient: grad,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                    border: Border.all(
                      color: glow.withValues(alpha: 0.45 + 0.20 * t),
                      width: isStar ? 0.8 : 0.6,
                    ),
                    boxShadow: [
                      BoxShadow(color: glow.withValues(alpha: glowAlpha), blurRadius: blur),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Üst-sol specular: hafif beyaz parlama (sabit)
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: Container(
                          height: 4,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x33FFFFFF), Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      if (label.isNotEmpty)
                        Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(1),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: isStar ? 8 : 5.5,
                                  fontWeight: FontWeight.w800,
                                  color: isStar
                                      ? const Color(0xFFFFD700)
                                      : Colors.white.withValues(alpha: 0.9),
                                  height: 1,
                                  shadows: const [Shadow(color: Color(0x80000000), blurRadius: 2)],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
          : Container(
              decoration: BoxDecoration(
                color: _kCellNormal,
                borderRadius: const BorderRadius.all(Radius.circular(3)),
                border: Border.all(
                  color: _kCellBorder.withValues(alpha: 0.7),
                  width: 0.6,
                ),
              ),
            ),
    );

    if (onDrop != null) {
      return _DroppableCell(
        onDrop: onDrop!,
        onEmptyTap: onEmptyTap,
        child: emptyCell,
      );
    }

    return emptyCell;
  }
}

// ── DragTarget yalnızca kendisi rebuild oluyor ───────────────────
// Ayrı StatefulWidget'a çıkarmak, _CellView'in geri kalanını
// sürükleme sırasında yeniden build etmekten korur.

class _DroppableCell extends StatefulWidget {
  final void Function(GameTile) onDrop;
  final VoidCallback? onEmptyTap;
  final Widget child;

  const _DroppableCell({
    required this.onDrop,
    required this.child,
    this.onEmptyTap,
  });

  @override
  State<_DroppableCell> createState() => _DroppableCellState();
}

class _DroppableCellState extends State<_DroppableCell> {
  bool _hot = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<GameTile>(
      onWillAcceptWithDetails: (_) {
        if (!_hot) {
          setState(() => _hot = true);
          HapticService.instance.cellHover();
        }
        return true;
      },
      onLeave: (_) {
        if (_hot) setState(() => _hot = false);
      },
      onAcceptWithDetails: (d) {
        setState(() => _hot = false);
        HapticService.instance.tileDrop();
        widget.onDrop(d.data);
      },
      builder: (context, _, __) {
        return GestureDetector(
          onTap: widget.onEmptyTap,
          child: _hot
              ? TweenAnimationBuilder<double>(
                  key: const ValueKey('hot-ring'),
                  tween: Tween(begin: 0.85, end: 1.0),
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.all(Radius.circular(5)),
                      border: Border.all(color: _kPrimary, width: 2.2),
                      boxShadow: const [
                        BoxShadow(color: Color(0xAA4CAF50), blurRadius: 12, spreadRadius: 1.5),
                        BoxShadow(color: Color(0x554CAF50), blurRadius: 22, spreadRadius: 4),
                      ],
                    ),
                    child: widget.child,
                  ),
                )
              : widget.child,
        );
      },
    );
  }
}

// ── Taş içeriği (paylaşılan) ─────────────────────────────────────

class _TileContent extends StatelessWidget {
  final String letter;
  final int    pts;
  final bool   isPending;

  const _TileContent({required this.letter, required this.pts, required this.isPending});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Üst specular — pending taşta parlak, kilitli taşta hafif
        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              gradient: LinearGradient(
                colors: [
                  Color(isPending ? 0x80FFFFFF : 0x40FFFFFF),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        // Kilitli taşta sol kenar yumuşak iç gölge (depth)
        if (!isPending)
          Positioned(
            left: 0, top: 0, bottom: 0,
            child: Container(
              width: 2,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(3)),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x33000000), Colors.transparent],
                ),
              ),
            ),
          ),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(1, 1, 3, 5),
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _kTileText,
                  height: 1,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 2, bottom: 1,
          child: Text(
            '$pts',
            style: TextStyle(
              fontSize: 5.5,
              fontWeight: FontWeight.bold,
              color: isPending ? _kTilePoints : _kTilePoints.withValues(alpha: 0.8),
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Baskı ölçek sarmalayıcı ──────────────────────────────────────

class _PressScaleWrap extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _PressScaleWrap({required this.child, this.onTap});

  @override
  State<_PressScaleWrap> createState() => _PressScaleWrapState();
}

class _PressScaleWrapState extends State<_PressScaleWrap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 70),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ── Sürükleme geri bildirimi ─────────────────────────────────────

class _DragFeedback extends StatelessWidget {
  final String letter;
  final int    points;
  const _DragFeedback({required this.letter, required this.points});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Transform.rotate(
        angle: 0.08,
        child: Transform.scale(
          scale: 1.22,
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF8E1), Color(0xFFE8A000)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(5)),
              border: Border.fromBorderSide(BorderSide(color: _kTilePendBord, width: 1.5)),
              boxShadow: [
                BoxShadow(color: Color(0x99FFA000), blurRadius: 10, spreadRadius: 1),
                BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(3, 5)),
              ],
            ),
            child: Stack(children: [
              Center(
                child: Text(letter,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kTileText,
                      height: 1,
                    )),
              ),
              Positioned(
                right: 3, bottom: 2,
                child: Text('$points',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: _kTilePoints,
                    )),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
