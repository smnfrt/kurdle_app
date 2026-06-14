import 'package:flutter/material.dart';

/// HomeScreen ana ekranda "Oyunlarım" sheet'ini açmasını isteyen global tetikleyici.
/// Sayfalar (örn. friend_game_screen) çıkışta `homeOpenMyGamesTick.value++` çağırır;
/// HomeScreen bu listener'a bağlıdır.
final ValueNotifier<int> homeOpenMyGamesTick = ValueNotifier<int>(0);

const Duration _kAppRouteIn = Duration(milliseconds: 190);
const Duration _kAppRouteOut = Duration(milliseconds: 160);
const Duration _kAppSheetIn = Duration(milliseconds: 220);
const Duration _kAppSheetOut = Duration(milliseconds: 160);

/// Hafif page transition: subtle slide-up + fade.
/// Menülerden oyuna geçişte kopukluk hissini azaltmak için kısa ve tutarlı.
Route<T> appRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: _kAppRouteIn,
    reverseTransitionDuration: _kAppRouteOut,
    transitionsBuilder: (_, animation, __, child) {
      final inCurve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuart,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: Tween<double>(begin: 0.0, end: 1.0).animate(inCurve),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.025),
            end: Offset.zero,
          ).animate(inCurve),
          child: child,
        ),
      );
    },
  );
}

Future<T?> showAppModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final controller = BottomSheet.createAnimationController(navigator.overlay!);
  controller.duration = _kAppSheetIn;
  controller.reverseDuration = _kAppSheetOut;

  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    shape: shape,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    transitionAnimationController: controller,
  ).whenComplete(() {
    controller.dispose();
  });
}

class AppSheetDragHandle extends StatelessWidget {
  final Color color;
  final double width;
  final EdgeInsetsGeometry margin;

  const AppSheetDragHandle({
    super.key,
    required this.color,
    this.width = 42,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width + 32,
      height: 28,
      alignment: Alignment.center,
      margin: margin,
      child: Container(
        width: width,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
