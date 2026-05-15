import 'package:flutter/material.dart';

/// HomeScreen ana ekranda "Oyunlarım" sheet'ini açmasını isteyen global tetikleyici.
/// Sayfalar (örn. friend_game_screen) çıkışta `homeOpenMyGamesTick.value++` çağırır;
/// HomeScreen bu listener'a bağlıdır.
final ValueNotifier<int> homeOpenMyGamesTick = ValueNotifier<int>(0);

/// Hafif page transition: subtle slide-up + fade.
/// Kısa süre ve tek katmanlı animasyon, düşük/orta seviye telefonlarda daha akıcıdır.
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 240),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (_, animation, __, child) {
      final inCurve = CurvedAnimation(
        parent: animation,
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
          child: child,
        ),
      );
    },
  );
}
