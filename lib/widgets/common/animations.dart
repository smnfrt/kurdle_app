import 'package:flutter/material.dart';

/// Basıldığında hafifçe küçülen press-feedback sarmalayıcı (genel-amaçlı).
/// (home_screen.dart'tan ortak konuma çıkarıldı — davranış birebir korunur.)
class PressableScale extends StatefulWidget {
  final Widget child;

  const PressableScale({super.key, required this.child});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerCancel: (_) => _setPressed(false),
      onPointerUp: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Nabız gibi yumuşak parlayan glow sarmalayıcı (genel-amaçlı).
class PulseGlow extends StatefulWidget {
  final Color color;
  final Widget child;

  const PulseGlow({
    super.key,
    required this.color,
    required this.child,
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_ctrl.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.16 + (0.13 * t)),
                blurRadius: 18 + (10 * t),
                spreadRadius: 0.5 + (1.5 * t),
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
