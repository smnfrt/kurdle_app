import 'package:flutter/material.dart';
import 'package:kurdle_app/services/word_steal_service.dart';

// ── Renkler ───────────────────────────────────────────────────────
const _kBg     = Color(0xFF0D2A2A);
const _kBorder = Color(0xFF00BFA5);
const _kAccent = Color(0xFF1DE9B6);
const _kGold   = Color(0xFFFFD700);

/// Tahtanın üstüne overlay olarak yerleşir; çalma gerçekleşince
/// aşağı iner, [duration] kadar bekler, ardından kaybolur.
///
/// Örnek kullanım (game screen içinden):
/// ```dart
/// void _showStealBanner(StealResult result) {
///   final overlay = Overlay.of(context);
///   late OverlayEntry entry;
///   entry = OverlayEntry(
///     builder: (_) => StealBannerWidget(
///       result:   result,
///       onDismiss: () => entry.remove(),
///     ),
///   );
///   overlay.insert(entry);
/// }
/// ```
class StealBannerWidget extends StatefulWidget {
  final StealResult result;
  final VoidCallback onDismiss;
  final Duration duration;

  const StealBannerWidget({
    super.key,
    required this.result,
    required this.onDismiss,
    this.duration = const Duration(milliseconds: 2600),
  });

  @override
  State<StealBannerWidget> createState() => _StealBannerWidgetState();
}

class _StealBannerWidgetState extends State<StealBannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    // Giriş animasyonu → bekle → çıkış
    _ctrl.forward().then((_) {
      Future.delayed(widget.duration, () {
        if (mounted) _ctrl.reverse().then((_) => widget.onDismiss());
      });
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 24,
      right: 24,
      child: GestureDetector(
        onTap: () => _ctrl.reverse().then((_) => widget.onDismiss()),
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kBorder, width: 1.8),
                  boxShadow: [
                    BoxShadow(
                      color: _kAccent.withValues(alpha: 0.30),
                      blurRadius: 24,
                      spreadRadius: 3,
                    ),
                    const BoxShadow(
                      color: Colors.black54,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Başlık ──────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎯 ', style: TextStyle(fontSize: 18)),
                        Text(
                          'KELIME ÇALINDI!',
                          style: TextStyle(
                            color: _kAccent,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(height: 1, color: _kBorder.withValues(alpha: 0.3)),
                    const SizedBox(height: 10),

                    // ── Kelime dönüşümü ─────────────────────
                    _WordTransformRow(result: r),
                    const SizedBox(height: 12),

                    // ── Bonus bilgisi ───────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _BonusPill(
                          label: '+${r.addedCount} harf',
                          color: _kAccent,
                        ),
                        const SizedBox(width: 8),
                        _BonusPill(
                          label: '+5 çalma',
                          color: _kGold,
                        ),
                        const SizedBox(width: 8),
                        _BonusPill(
                          label: '= +${r.bonusScore} bonus',
                          color: Colors.white,
                          bold: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Yardımcı widget'lar ───────────────────────────────────────────

/// "ROJ → ROJA" tarzı dönüşüm satırı; yeni harfler vurgulanır.
class _WordTransformRow extends StatelessWidget {
  final StealResult result;
  const _WordTransformRow({required this.result});

  @override
  Widget build(BuildContext context) {
    final newIndicesSet = result.newIndices.toSet();
    final chars = result.newWord.characters.toList();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Eski kelime (gri üstü çizili)
        Text(
          result.baseWord,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 14,
            decoration: TextDecoration.lineThrough,
            decorationColor: Colors.white38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward_rounded, color: _kBorder, size: 18),
        ),
        // Yeni kelime — yeni harfler vurgulu
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(chars.length, (i) {
            final isNew = newIndicesSet.contains(i);
            return _AnimatedLetter(letter: chars[i], isNew: isNew, index: i);
          }),
        ),
      ],
    );
  }
}

/// Tek harf kutusu; yeni harfler teal renkte animasyonla belirir.
class _AnimatedLetter extends StatelessWidget {
  final String letter;
  final bool   isNew;
  final int    index;
  const _AnimatedLetter({required this.letter, required this.isNew, required this.index});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: isNew ? 0.0 : 1.0, end: 1.0),
      duration: Duration(milliseconds: isNew ? 350 + index * 40 : 0),
      curve: Curves.elasticOut,
      builder: (_, v, __) => Transform.scale(
        scale: v,
        child: Container(
          width: 22,
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: isNew
                ? _kAccent.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: isNew ? _kAccent : Colors.white24,
              width: isNew ? 1.5 : 0.8,
            ),
          ),
          child: Center(
            child: Text(
              letter,
              style: TextStyle(
                color: isNew ? _kAccent : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Renkli bonus etiketi.
class _BonusPill extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   bold;
  const _BonusPill({required this.label, required this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
        ),
      ),
    );
  }
}
