import 'package:flutter/material.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/connectivity_service.dart';

/// Ekranın üstünde, bağlantı kopunca aşağı kayan ince banner.
///
/// `MaterialApp.builder` içinden child'ı sarmalayan kullanım önerilir —
/// banner SafeArea'nın üstünde, mevcut layout'u hiç kaydırmaz (Stack).
/// Çevrimiçi olunca otomatik kayar gider, animasyon süresi 250 ms.
class OfflineBannerWrapper extends StatefulWidget {
  final Widget child;
  const OfflineBannerWrapper({super.key, required this.child});

  @override
  State<OfflineBannerWrapper> createState() => _OfflineBannerWrapperState();
}

class _OfflineBannerWrapperState extends State<OfflineBannerWrapper> {
  late bool _online;

  @override
  void initState() {
    super.initState();
    _online = ConnectivityService.instance.isOnline;
    ConnectivityService.instance.onStatusChange.listen((v) {
      if (mounted) setState(() => _online = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            ignoring: _online,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              offset: _online ? const Offset(0, -1) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _online ? 0 : 1,
                child: const _OfflinePill(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflinePill extends StatelessWidget {
  const _OfflinePill();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    L.offlineBanner,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
