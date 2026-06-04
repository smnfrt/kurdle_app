import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/level_rewards.dart';

/// Seviye atlama kutlama overlay'i.
///
/// `LevelUpOverlay.maybeShow` çağrılır — eğer `oldLevel < newLevel` ise
/// tam ekran modal açılır, kazanılan ödülleri (kLevelRewards) listeler.
class LevelUpOverlay {
  static Future<void> maybeShow({
    required BuildContext context,
    required int oldLevel,
    required int newLevel,
    int xpGained = 0,
    int peyvGained = 0,
  }) async {
    if (newLevel <= oldLevel) return;
    HapticFeedback.mediumImpact();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, _, __) {
        final scale = Curves.easeOutBack.transform(anim.value.clamp(0.0, 1.0));
        return Opacity(
          opacity: anim.value.clamp(0.0, 1.0),
          child: Center(
            child: Transform.scale(
              scale: 0.85 + 0.15 * scale,
              child: _LevelUpCard(
                oldLevel: oldLevel,
                newLevel: newLevel,
                xpGained: xpGained,
                peyvGained: peyvGained,
                onClose: () => Navigator.of(ctx).pop(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LevelUpCard extends StatelessWidget {
  final int oldLevel;
  final int newLevel;
  final int xpGained;
  final int peyvGained;
  final VoidCallback onClose;

  const _LevelUpCard({
    required this.oldLevel,
    required this.newLevel,
    required this.xpGained,
    required this.peyvGained,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A2535) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF18242C);
    final muted = fg.withValues(alpha: 0.7);
    final isTr = L.current == AppLocale.tr;

    // Bu atlama aralığındaki ödüller (oldLevel+1 .. newLevel)
    final unlocked = kLevelRewards
        .where((r) => r.level > oldLevel && r.level <= newLevel)
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header — altın gradient
          Container(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  child: const Icon(Icons.military_tech_rounded,
                      color: Colors.white, size: 38),
                ),
                const SizedBox(height: 12),
                Text(
                  isTr ? 'Seviye Atladın!' : 'Te Ast Hilkişand!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${isTr ? 'Seviye' : 'Asta'} $oldLevel → $newLevel',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Kazanım özeti
          if (xpGained > 0 || peyvGained > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (xpGained > 0) ...[
                    _RewardChip(
                      icon: Icons.bolt_rounded,
                      color: const Color(0xFFFFD700),
                      label: '+$xpGained XP',
                    ),
                    if (peyvGained > 0) const SizedBox(width: 10),
                  ],
                  if (peyvGained > 0)
                    _RewardChip(
                      icon: Icons.savings_rounded,
                      color: const Color(0xFF00BFA5),
                      label: '+$peyvGained Peyv',
                    ),
                ],
              ),
            ),

          // Açılan ödüller listesi
          if (unlocked.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  isTr ? 'Yeni Açılan Ödüller' : 'Xelatên Nû Vebûyî',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: unlocked
                    .map((r) => _RewardRow(reward: r, fg: fg, isTr: isTr))
                    .toList(),
              ),
            ),
          ],

          // Kapat butonu
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onClose,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFA000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  isTr ? 'Devam Et' : 'Berdewam bike',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _RewardChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final LevelReward reward;
  final Color fg;
  final bool isTr;
  const _RewardRow({
    required this.reward,
    required this.fg,
    required this.isTr,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: reward.accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: reward.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(reward.icon, color: reward.accent, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              isTr ? reward.trTitle : reward.kuTitle,
              style: TextStyle(
                  color: fg, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: reward.accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'L${reward.level}',
              style: TextStyle(
                  color: reward.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
