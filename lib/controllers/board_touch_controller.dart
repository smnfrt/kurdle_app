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
  Size contentSize = Size.zero;

  bool _panEnabled = false;
  bool get panEnabled => _panEnabled;
  bool _isClamping = false;
  bool _gestureActive = false;

  // ── Inertia state ────────────────────────────────────────────────
  double _scale = 1.0;
  Offset _position = Offset.zero;
  Offset _velocity = Offset.zero;

  static const double _friction = 0.84; // kare başına hız azalması
  static const double _stopThreshold = 3.0; // px/kare altında dur
  static const double _bounce = 0.12; // kenar yansıma katsayısı
  static const double _liveOverscroll = 28.0;

  void zoomToBoardCenter({double scale = 2.05}) {
    if (viewportSize == Size.zero || scale <= 1.0) return;
    final boardSize = contentSize == Size.zero ? viewportSize : contentSize;
    final focus = Offset(boardSize.width / 2, boardSize.height / 2);
    final target = Offset(viewportSize.width / 2, viewportSize.height / 2);

    _ticker.stop();
    _gestureActive = false;
    _velocity = Offset.zero;
    _scale = scale;
    _position = _clampedPosition(target - focus * scale, _scale);
    _setTransform(Matrix4.identity()
      ..translate(_position.dx, _position.dy)
      ..scale(_scale));

    if (!_panEnabled) {
      _panEnabled = true;
      _onPanChanged(true);
    }
  }

  // ── TransformationController listener ───────────────────────────
  void onTransformChanged() {
    if (_isClamping) return;
    final m = _transformCtrl.value;
    final scale = m.getMaxScaleOnAxis();
    final shouldPan = scale > 1.01;

    if (shouldPan != _panEnabled) {
      _panEnabled = shouldPan;
      _onPanChanged(shouldPan);
    }

    if (!shouldPan) {
      _ticker.stop();
      _velocity = Offset.zero;
      if (!_gestureActive && !_isIdentityish(m)) {
        _setTransform(Matrix4.identity());
      }
    } else {
      _softClamp(m, scale);
    }
  }

  // ── Gesture başladı: devam eden inertia'yı durdur ────────────────
  void onGestureStart() {
    _gestureActive = true;
    _ticker.stop();
    _velocity = Offset.zero;
  }

  // ── Gesture bitti: inertia başlat ────────────────────────────────
  void onGestureEnd(Offset velocityPxPerSec) {
    _gestureActive = false;
    if (!_panEnabled) {
      _setTransform(Matrix4.identity());
      return;
    }
    final m = _transformCtrl.value;
    _scale = m.getMaxScaleOnAxis();
    _position = Offset(m.entry(0, 3), m.entry(1, 3));
    // px/saniye → px/kare (60fps)
    _velocity = velocityPxPerSec / 60.0;
    if (_velocity.distance > _stopThreshold) {
      _ticker.stop();
      _ticker.start();
    } else {
      _position = _clampedPosition(_position, _scale);
      _setTransform(Matrix4.identity()
        ..translate(_position.dx, _position.dy)
        ..scale(_scale));
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

    final clamped = _clampedPosition(_position, _scale);
    if (clamped.dx != _position.dx) {
      _velocity = Offset(-_velocity.dx * _bounce, _velocity.dy);
    }
    if (clamped.dy != _position.dy) {
      _velocity = Offset(_velocity.dx, -_velocity.dy * _bounce);
    }
    _position = clamped;

    final out = Matrix4.identity()
      ..translate(_position.dx, _position.dy)
      ..scale(_scale);
    _setTransform(out);
  }

  // ── Canlı gesture sırasında hafif toleranslı sınır ──────────────
  void _softClamp(Matrix4 m, double scale) {
    if (viewportSize == Size.zero) return;
    final tx = m.entry(0, 3);
    final ty = m.entry(1, 3);
    final vw = viewportSize.width;
    final vh = viewportSize.height;
    final content = contentSize == Size.zero ? viewportSize : contentSize;
    final minX =
        (vw - content.width * scale).clamp(double.negativeInfinity, 0.0);
    final minY =
        (vh - content.height * scale).clamp(double.negativeInfinity, 0.0);
    final cx = tx.clamp(minX - _liveOverscroll, _liveOverscroll);
    final cy = ty.clamp(minY - _liveOverscroll, _liveOverscroll);
    if ((tx - cx).abs() > 0.5 || (ty - cy).abs() > 0.5) {
      final out = m.clone();
      out.setEntry(0, 3, cx);
      out.setEntry(1, 3, cy);
      _setTransform(out);
    }
  }

  Offset _clampedPosition(Offset position, double scale) {
    if (viewportSize == Size.zero) return position;
    final vw = viewportSize.width;
    final vh = viewportSize.height;
    final content = contentSize == Size.zero ? viewportSize : contentSize;
    final minX =
        (vw - content.width * scale).clamp(double.negativeInfinity, 0.0);
    final minY =
        (vh - content.height * scale).clamp(double.negativeInfinity, 0.0);
    return Offset(
      position.dx.clamp(minX, 0.0),
      position.dy.clamp(minY, 0.0),
    );
  }

  bool _isIdentityish(Matrix4 m) {
    return (m.getMaxScaleOnAxis() - 1.0).abs() < 0.01 &&
        m.entry(0, 3).abs() < 0.5 &&
        m.entry(1, 3).abs() < 0.5;
  }

  void _setTransform(Matrix4 value) {
    _isClamping = true;
    _transformCtrl.value = value;
    _isClamping = false;
  }

  void dispose() => _ticker.dispose();
}
