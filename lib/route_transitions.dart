import 'package:flutter/material.dart';

/// HomeScreen ana ekranda "Oyunlarım" sheet'ini açmasını isteyen global tetikleyici.
/// Sayfalar (örn. friend_game_screen) çıkışta `homeOpenMyGamesTick.value++` çağırır;
/// HomeScreen bu listener'a bağlıdır.
final ValueNotifier<int> homeOpenMyGamesTick = ValueNotifier<int>(0);

/// Premium page transition: in: subtle slide-up + scale-in + fade.
/// Out: ortadaki sayfa hafif geride kalır (parallax depth effect).
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (_, animation, secondary, child) {
      final inCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final outCurve = CurvedAnimation(
        parent: secondary,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(inCurve),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.04),
            end: Offset.zero,
          ).animate(inCurve),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(inCurve),
            // Önceki sayfa: hafif geride kalsın (parallax depth)
            child: Transform.scale(
              scale: 1.0 - 0.03 * outCurve.value,
              child: Opacity(
                opacity: 1.0 - 0.18 * outCurve.value,
                child: child,
              ),
            ),
          ),
        ),
      );
    },
  );
}
