import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/services/app_warmup_service.dart';
import 'package:kurdle_app/widgets/brand_mark.dart';
import 'package:kurdle_app/widgets/home_screen.dart';

const _kBg = Color(0xFFF4F0D6);
const _kWarmLight = Color(0xFFFFF7D6);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _logoScale = Tween<double>(begin: 0.98, end: 1).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    unawaited(_logoCtrl.forward());
    await Future<void>.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;
    Navigator.of(context).pushReplacement(appRoute(const HomeScreen()));
    Timer(const Duration(milliseconds: 900), () {
      AppWarmupService.instance.startHomeWarmups();
    });
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          const Positioned.fill(child: _SplashBackdrop()),
          Center(
            child: AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) {
                return Transform.scale(
                  scale: _logoScale.value,
                  child: const PeyvokBrandMark(
                    size: 138,
                    radius: 34,
                    elevation: 42,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final ghostSize = (width * 1.34).clamp(430.0, 760.0);

        return Stack(
          children: [
            const Positioned.fill(
              child: CustomPaint(painter: _BoardTexturePainter()),
            ),
            Positioned(
              top: -height * 0.08,
              left: 0,
              right: 0,
              height: height * 0.58,
              child: const IgnorePointer(
                child: CustomPaint(painter: _OverheadLightPainter()),
              ),
            ),
            Positioned(
              left: (width - ghostSize) / 2,
              top: height * 0.18,
              child: IgnorePointer(
                child: Image.asset(
                  peyvokBrandIconAsset,
                  width: ghostSize,
                  height: ghostSize,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  opacity: const AlwaysStoppedAnimation(0.075),
                ),
              ),
            ),
            Positioned(
              left: width * 0.14,
              right: width * 0.14,
              top: height * 0.35,
              height: height * 0.22,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF315C20).withValues(alpha: 0.14),
                        blurRadius: 90,
                        spreadRadius: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OverheadLightPainter extends CustomPainter {
  const _OverheadLightPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.05);
    final beamPath = Path()
      ..moveTo(size.width * 0.37, 0)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.38,
        size.width * 0.62,
        size.height,
      )
      ..lineTo(size.width * 0.38, size.height)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.38,
        size.width * 0.63,
        0,
      )
      ..close();

    final beamPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.62),
          _kWarmLight.withValues(alpha: 0.34),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.42, 1],
      ).createShader(Offset.zero & size);
    canvas.drawPath(beamPath, beamPaint);

    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.86),
          _kWarmLight.withValues(alpha: 0.42),
          Colors.white.withValues(alpha: 0),
        ],
        stops: const [0, 0.42, 1],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.width * 0.34),
      );
    canvas.drawCircle(center, size.width * 0.34, haloPaint);
  }

  @override
  bool shouldRepaint(covariant _OverheadLightPainter oldDelegate) => false;
}

class _BoardTexturePainter extends CustomPainter {
  const _BoardTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final baseRect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFAE6),
          Color(0xFFF4F0D6),
          Color(0xFFEAE3BC),
        ],
      ).createShader(baseRect);
    canvas.drawRect(baseRect, bgPaint);

    final gridPaint = Paint()
      ..color = const Color(0xFF8BA56A).withValues(alpha: 0.075)
      ..strokeWidth = 1;
    const step = 58.0;
    final xOffset = (size.width % step) / 2;
    for (double x = xOffset; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 24; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.08),
        radius: 1.05,
        colors: [
          Colors.white.withValues(alpha: 0),
          const Color(0xFF7B6C2F).withValues(alpha: 0.10),
        ],
      ).createShader(baseRect);
    canvas.drawRect(baseRect, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant _BoardTexturePainter oldDelegate) => false;
}
