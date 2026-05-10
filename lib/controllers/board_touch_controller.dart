import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Pan + inertia + kenar-bounce yöneticisi.
/// Scale=1 iken pan tamamen kapalıdır; scale>1 iken aktif olur.
class BoardTouchController {
  BoardTouchController({
    required TransformationController transformCtrl,
    required TickerProvider vsync,
    required void Function(bool panEnabled) onPanChanged,
  })  : _transformCtrl = transformCtrl,
        _onPanChanged = onPanChanged {
    _ticker = vsync.createTicker(_tick);
  }

  final TransformationController _transformCtrl;
  final void Function(bool) _onPanChanged;
  late final Ticker _ticker;

  /// LayoutBuilder'dan gelen anlık viewport boyutu.
  Size viewportSize = Size.zero;

  bool _panEnabled = false;
  bool get panEnabled => _panEnabled;
  bool _isClamping = false;

  // ── Inertia state ────────────────────────────────────────────────
  double _scale = 1.0;
  Offset _position = Offset.zero;
  Offset _velocity = Offset.zero;

  static const double _friction      = 0.88;  // kare başına hız azalması
  static const double _stopThreshold = 4.0;   // px/kare altında dur
  static const double _bounce        = 0.18;  // kenar yansıma katsayısı

  // ── TransformationController listener ───────────────────────────
  void onTransformChanged() {
    if (_isClamping) return;
    final m     = _transformCtrl.value;
    final scale = m.getMaxScaleOnAxis();
    final shouldPan = scale > 1.01;

    if (shouldPan != _panEnabled) {
      _panEnabled = shouldPan;
      _onPanChanged(shouldPan);
    }

    if (!shouldPan) {
      _ticker.stop();
      _velocity = Offset.zero;
      // Scale 1'e döndüğünde pozisyonu sıfırla
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_transformCtrl.value.getMaxScaleOnAxis() <= 1.01) {
          _transformCtrl.value = Matrix4.identity();
        }
      });
    } else {
      _hardClamp(m, scale);
    }
  }

  // ── Gesture başladı: devam eden inertia'yı durdur ────────────────
  void onGestureStart() {
    _ticker.stop();
    _velocity = Offset.zero;
  }

  // ── Gesture bitti: inertia başlat ────────────────────────────────
  void onGestureEnd(Offset velocityPxPerSec) {
    if (!_panEnabled) return;
    final m = _transformCtrl.value;
    _scale    = m.getMaxScaleOnAxis();
    _position = Offset(m.entry(0, 3), m.entry(1, 3));
    // px/saniye → px/kare (60fps)
    _velocity = velocityPxPerSec / 60.0;
    if (_velocity.distance > _stopThreshold) {
      _ticker.stop();
      _ticker.start();
    }
  }

  // ── Inertia + bounce kare döngüsü ───────────────────────────────
  void _tick(Duration _) {
    if (!_panEnabled || viewportSize == Size.zero) {
      _ticker.stop();
      return;
    }

    _velocity = _velocity * _friction;
    if (_velocity.distance < _stopThreshold) {
      _ticker.stop();
      _velocity = Offset.zero;
      return;
    }

    _position += _velocity;

    final vw   = viewportSize.width;
    final vh   = viewportSize.height;
    final minX = vw * (1 - _scale);
    final minY = vh * (1 - _scale);

    // Sağ/sol kenarda bounce
    if (_position.dx > 0) {
      _position = Offset(0, _position.dy);
      _velocity = Offset(-_velocity.dx * _bounce, _velocity.dy);
    } else if (_position.dx < minX) {
      _position = Offset(minX, _position.dy);
      _velocity = Offset(-_velocity.dx * _bounce, _velocity.dy);
    }
    // Üst/alt kenarda bounce
    if (_position.dy > 0) {
      _position = Offset(_position.dx, 0);
      _velocity = Offset(_velocity.dx, -_velocity.dy * _bounce);
    } else if (_position.dy < minY) {
      _position = Offset(_position.dx, minY);
      _velocity = Offset(_velocity.dx, -_velocity.dy * _bounce);
    }

    final out = Matrix4.identity()
      ..translate(_position.dx, _position.dy)
      ..scale(_scale);
    _isClamping = true;
    _transformCtrl.value = out;
    _isClamping = false;
  }

  // ── Canlı gesture sırasında sert sınır ──────────────────────────
  void _hardClamp(Matrix4 m, double scale) {
    if (viewportSize == Size.zero) return;
    final tx = m.entry(0, 3);
    final ty = m.entry(1, 3);
    final vw = viewportSize.width;
    final vh = viewportSize.height;
    final cx = tx.clamp(vw * (1 - scale), 0.0);
    final cy = ty.clamp(vh * (1 - scale), 0.0);
    if ((tx - cx).abs() > 0.5 || (ty - cy).abs() > 0.5) {
      final out = m.clone();
      out.setEntry(0, 3, cx);
      out.setEntry(1, 3, cy);
      _isClamping = true;
      _transformCtrl.value = out;
      _isClamping = false;
    }
  }

  void dispose() => _ticker.dispose();
}
