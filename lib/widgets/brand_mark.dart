import 'package:flutter/material.dart';

const leyarBrandIconAsset = 'assets/branding/icon-1024.png';

class LeyarBrandMark extends StatelessWidget {
  final double size;
  final double radius;
  final double elevation;

  const LeyarBrandMark({
    super.key,
    required this.size,
    this.radius = 22,
    this.elevation = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3F7F2A).withValues(alpha: 0.22),
            blurRadius: elevation,
            spreadRadius: -elevation * 0.32,
            offset: Offset(0, elevation * 0.36),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        leyarBrandIconAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
