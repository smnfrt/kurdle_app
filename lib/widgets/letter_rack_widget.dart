import 'package:flutter/material.dart';
import 'package:kurdle_app/models/game_tile.dart';

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
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6D4C41), Color(0xFF4E342E)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 3)),
        ],
        border: Border.all(color: const Color(0xFF3E2723), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: tiles.isEmpty
            ? [const Text('Harf kalmadı', style: TextStyle(color: Colors.white38, fontSize: 13))]
            : tiles
                .map((tile) => _TileWidget(
                      tile: tile,
                      enabled: enabled,
                      isSelected: tile.id == selectedTileId,
                      onTap: onTileTap != null ? () => onTileTap!(tile) : null,
                    ))
                .toList(),
      ),
    );
  }
}

class _TileWidget extends StatelessWidget {
  final GameTile tile;
  final bool enabled;
  final bool isSelected;
  final VoidCallback? onTap;

  const _TileWidget({
    required this.tile,
    required this.enabled,
    required this.isSelected,
    this.onTap,
  });

  Widget _face({double scale = 1.0, bool selected = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 42 * scale,
      height: 50 * scale,
      margin: EdgeInsets.symmetric(horizontal: 2 * scale),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: selected
              ? [const Color(0xFFFFEE58), const Color(0xFFFFC107)]
              : [const Color(0xFFFFF8E1), const Color(0xFFE8C46A)],
        ),
        borderRadius: BorderRadius.circular(7 * scale),
        border: Border.all(
          color: selected ? const Color(0xFFFF8F00) : const Color(0xFFB8860B),
          width: selected ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: selected
                ? const Color(0xFFFFC107).withOpacity(0.6)
                : Colors.black.withOpacity(0.35),
            blurRadius: selected ? 8 * scale : 4 * scale,
            offset: Offset(1.5 * scale, 2.5 * scale),
            spreadRadius: selected ? 1 : 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 5 * scale,
            right: 5 * scale,
            top: 8 * scale,
            child: Container(height: 0.5, color: Colors.brown.withOpacity(0.15)),
          ),
          Center(
            child: Text(
              tile.letter,
              style: TextStyle(
                fontSize: 20 * scale,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF3E2723),
                height: 1,
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
                fontWeight: FontWeight.bold,
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
    if (!enabled) return _face();

    return GestureDetector(
      onTap: onTap,
      child: Draggable<GameTile>(
        data: tile,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.2, child: _face(scale: 1.0)),
        ),
        childWhenDragging: Opacity(opacity: 0.25, child: _face()),
        child: _face(selected: isSelected),
      ),
    );
  }
}
