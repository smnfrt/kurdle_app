import 'package:flutter/material.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/services/sound_service.dart';
import 'package:kurdle_app/services/haptic_service.dart';

class LetterRackWidget extends StatelessWidget {
  final List<GameTile> tiles;
  final bool enabled;
  final String? selectedTileId;
  final void Function(GameTile)? onTileTap;

  const LetterRackWidget({
    Key? key,
    required this.tiles,
    this.enabled = true,
    this.selectedTileId,
    this.onTileTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF7E5A48),
            Color(0xFF5C3A2A),
            Color(0xFF3E2620),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.04),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(color: const Color(0xFF2A1A14), width: 1),
      ),
      child: Stack(
        children: [
          // Üst ışık çizgisi
          Positioned(
            top: 0, left: 8, right: 8,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0),
                    Colors.white.withOpacity(0.18),
                    Colors.white.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: tiles.isEmpty
                ? [const Text('Harf kalmadı',
                    style: TextStyle(color: Colors.white38, fontSize: 13))]
                : tiles
                    .map((tile) => _TileWidget(
                          key: ValueKey('rack-${tile.id}'),
                          tile: tile,
                          enabled: enabled,
                          isSelected: tile.id == selectedTileId,
                          onTap: onTileTap != null ? () => onTileTap!(tile) : null,
                        ))
                    .toList(),
          ),
        ],
      ),
    );
  }
}

class _TileWidget extends StatefulWidget {
  final GameTile tile;
  final bool enabled;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TileWidget({
    super.key,
    required this.tile,
    required this.enabled,
    required this.isSelected,
    this.onTap,
  });

  @override
  State<_TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<_TileWidget> with TickerProviderStateMixin {
  late final AnimationController _press;
  late final AnimationController _selectedPulse;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 320),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _selectedPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isSelected) _selectedPulse.repeat(reverse: true);

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _TileWidget old) {
    super.didUpdateWidget(old);
    if (widget.isSelected && !_selectedPulse.isAnimating) {
      _selectedPulse.repeat(reverse: true);
    } else if (!widget.isSelected) {
      _selectedPulse.stop();
      _selectedPulse.value = 0.0;
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _selectedPulse.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _handleDown(_) {
    _press.forward();
  }

  void _handleUp(_) {
    // Bounce-back: forward duration kısa, reverse-with-elastic uzun
    _press.reverse();
  }

  void _handleCancel() {
    _press.reverse();
  }

  Widget _face({double scale = 1.0, bool selected = false, bool isFeedback = false}) {
    final tile = widget.tile;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: 42 * scale,
      height: 52 * scale,
      margin: EdgeInsets.symmetric(horizontal: 2.5 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? const [Color(0xFFFFF59D), Color(0xFFFFB300)]
              : const [
                  Color(0xFFFFFAEB),
                  Color(0xFFF3DCA0),
                  Color(0xFFD8AB54),
                ],
          stops: selected ? const [0.0, 1.0] : const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(8 * scale),
        border: Border.all(
          color: selected ? const Color(0xFFFF8F00) : const Color(0xFF8B5A1F),
          width: selected ? 2.0 : 1.0,
        ),
        boxShadow: [
          // Derin gölge
          BoxShadow(
            color: Colors.black.withOpacity(isFeedback ? 0.50 : 0.42),
            blurRadius: isFeedback ? 12 * scale : 5 * scale,
            offset: Offset(isFeedback ? 4 * scale : 1.5 * scale,
                isFeedback ? 8 * scale : 3 * scale),
          ),
          // İç parlama (rim light)
          BoxShadow(
            color: Colors.white.withOpacity(0.15),
            blurRadius: 1,
            offset: const Offset(0, -0.5),
            spreadRadius: -1,
          ),
          if (selected)
            BoxShadow(
              color: const Color(0xFFFFC107).withOpacity(0.55),
              blurRadius: 12 * scale,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Üst yansıma katmanı
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 14 * scale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(8 * scale)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.55),
                    Colors.white.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          // Alt iç gölge
          Positioned(
            left: 4 * scale,
            right: 4 * scale,
            bottom: 4 * scale,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                color: const Color(0xFF8B5A1F).withOpacity(0.18),
                borderRadius: BorderRadius.circular(0.5),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 3 * scale),
              child: Text(
                tile.letter,
                style: TextStyle(
                  fontSize: 22 * scale,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2C1810),
                  height: 1,
                  letterSpacing: -0.3,
                  shadows: [
                    Shadow(
                      color: Colors.white.withOpacity(0.35),
                      offset: const Offset(0, 1),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 4 * scale,
            bottom: 3 * scale,
            child: Text(
              '${tile.points}',
              style: TextStyle(
                fontSize: 9 * scale,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF6D4C41),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return AnimatedBuilder(
        animation: _entrance,
        builder: (_, __) {
          final v = Curves.easeOutBack.transform(_entrance.value.clamp(0.0, 1.0));
          return Transform.scale(scale: 0.85 + 0.15 * v, child: _face());
        },
      );
    }

    return GestureDetector(
      onTapDown: _handleDown,
      onTapUp: _handleUp,
      onTapCancel: _handleCancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, _selectedPulse, _entrance]),
        builder: (_, __) {
          // Press'in custom curve'ü: ileri eklenirken sıkışır, dönerken elastic ile geri zıplar
          final pressForward =
              Curves.easeOut.transform(_press.value.clamp(0.0, 1.0));
          final pressReverse = _press.status == AnimationStatus.reverse
              ? Curves.elasticOut.transform(1 - _press.value)
              : 0.0;

          // Press: 1.0 → 0.88 (forward), reverse: bounce back to 1.0
          final scale = 1.0 - 0.12 * pressForward + 0.04 * pressReverse;
          final tilt = -0.04 * pressForward;
          final entranceScale = Curves.easeOutBack
              .transform(_entrance.value.clamp(0.0, 1.0));
          final selectedLift =
              widget.isSelected ? -3.0 - 2.0 * _selectedPulse.value : 0.0;

          return Transform.translate(
            offset: Offset(0, selectedLift),
            child: Transform.scale(
              scale: scale * (0.85 + 0.15 * entranceScale),
              child: Transform.rotate(
                angle: tilt,
                child: Draggable<GameTile>(
                  data: widget.tile,
                  onDragStarted: () {
                    _press.value = 0.0;
                    SoundService.instance.play(SFX.tilePickup);
                    HapticService.instance.tilePickup();
                  },
                  onDraggableCanceled: (_, __) {
                    SoundService.instance.play(SFX.tileReturn);
                    HapticService.instance.tileReturn();
                  },
                  feedback: Material(
                    color: Colors.transparent,
                    child: Transform.rotate(
                      angle: 0.06,
                      child: Transform.scale(
                        scale: 1.18,
                        child: _face(scale: 1.0, isFeedback: true),
                      ),
                    ),
                  ),
                  childWhenDragging: Opacity(opacity: 0.18, child: _face()),
                  child: _face(selected: widget.isSelected),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
