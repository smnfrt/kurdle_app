import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';

/// Peyv mağazası — kullanıcı kazandığı Peyv'i oyun-içi item'lara harcar.
///
/// Üç giriş noktası:
/// 1. Profile ekranı — sadece keşif (item satın alma henüz oyun-içi anlamı yok)
/// 2. Scrabble oyunu — +1 Enhance / +1 Steal (controller'a apply edilir)
/// 3. Wordle oyunu — Harf İpucu
///
/// `enableInGameItems` true ise oyun-içi item'lar görünür (Enhance/Steal/Hint).
/// `onItemPurchased` satın alım başarılı olunca caller'a haber verir;
/// caller `itemKey`'e göre efekti uygular (ör. controller.maxStealsPerGame++).

enum PeyvItem {
  scrabbleExtraEnhance,
  scrabbleExtraSteal,
  wordleHint,
  dailyRetry,
}

class PeyvShopItem {
  final PeyvItem key;
  final IconData icon;
  final Color color;
  final String trLabel;
  final String kuLabel;
  final String trDesc;
  final String kuDesc;
  final int cost;
  const PeyvShopItem({
    required this.key,
    required this.icon,
    required this.color,
    required this.trLabel,
    required this.kuLabel,
    required this.trDesc,
    required this.kuDesc,
    required this.cost,
  });
}

const _allItems = <PeyvShopItem>[
  PeyvShopItem(
    key: PeyvItem.scrabbleExtraEnhance,
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFFFD700),
    trLabel: '+1 Geliştirme',
    kuLabel: '+1 Pêşkeftin',
    trDesc: 'Şu anki Scrabble oyununa 1 ekstra geliştirme hakkı.',
    kuDesc: 'Lîstika Scrabble ya niha re 1 mafê Pêşkeftin a zêde.',
    cost: 30,
  ),
  PeyvShopItem(
    key: PeyvItem.scrabbleExtraSteal,
    icon: Icons.flash_on_rounded,
    color: Color(0xFFFF6F00),
    trLabel: '+1 Çalma',
    kuLabel: '+1 Dizîn',
    trDesc: 'Şu anki Scrabble oyununa 1 ekstra çalma hakkı.',
    kuDesc: 'Lîstika Scrabble ya niha re 1 mafê Dizîn a zêde.',
    cost: 50,
  ),
  PeyvShopItem(
    key: PeyvItem.wordleHint,
    icon: Icons.lightbulb_rounded,
    color: Color(0xFFFFB300),
    trLabel: 'Wordle Harf İpucu',
    kuLabel: 'Şîreta Tîpê ya Wordle',
    trDesc: 'Cevaptaki bir harfi rastgele açar.',
    kuDesc: 'Tîpekê ji bersivê bi tesadufî vekirin.',
    cost: 25,
  ),
  PeyvShopItem(
    key: PeyvItem.dailyRetry,
    icon: Icons.refresh_rounded,
    color: Color(0xFF42A5F5),
    trLabel: 'Daily Yeniden Başlat',
    kuLabel: 'Daily Dîsa Destpêk',
    trDesc: 'Bugünkü daily challenge\'ı yeniden oyna.',
    kuDesc: 'Challenge ya rojane ya îro dîsa bilîze.',
    cost: 40,
  ),
];

class PeyvShopSheet extends StatefulWidget {
  final int currentPeyv;
  final int playerLevel;
  final Set<PeyvItem> enabledItems;
  // showLocked: kilitli item'ları gri olarak göster ("L6 gerekli" rozeti ile).
  // Profile bağlamında true, oyun-içi bağlamlarda false.
  final bool showLocked;
  final void Function(PeyvItem item)? onItemPurchased;
  const PeyvShopSheet({
    super.key,
    required this.currentPeyv,
    required this.playerLevel,
    required this.enabledItems,
    this.showLocked = false,
    this.onItemPurchased,
  });

  static Future<void> show({
    required BuildContext context,
    required int currentPeyv,
    required int playerLevel,
    required Set<PeyvItem> enabledItems,
    bool showLocked = false,
    void Function(PeyvItem item)? onItemPurchased,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PeyvShopSheet(
        currentPeyv: currentPeyv,
        playerLevel: playerLevel,
        enabledItems: enabledItems,
        showLocked: showLocked,
        onItemPurchased: onItemPurchased,
      ),
    );
  }

  @override
  State<PeyvShopSheet> createState() => _PeyvShopSheetState();
}

class _PeyvShopSheetState extends State<PeyvShopSheet> {
  late int _balance;
  bool _busy = false;
  PeyvItem? _busyItem;

  bool _isLevelGated(PeyvItem item) {
    switch (item) {
      case PeyvItem.wordleHint:
      case PeyvItem.dailyRetry:
        return true;
      case PeyvItem.scrabbleExtraEnhance:
      case PeyvItem.scrabbleExtraSteal:
        return false;
    }
  }

  int _unlockLevelFor(PeyvItem item) {
    switch (item) {
      case PeyvItem.wordleHint:
        return 6;
      case PeyvItem.dailyRetry:
        return 7;
      default:
        return 1;
    }
  }

  bool _isLocked(PeyvItem item) {
    // enabledItems set'inde varsa kilitsiz (caller bağlamı zaten unlocked).
    if (widget.enabledItems.contains(item)) return false;
    if (!_isLevelGated(item)) return false;
    return widget.playerLevel < _unlockLevelFor(item);
  }

  @override
  void initState() {
    super.initState();
    _balance = widget.currentPeyv;
  }

  Future<void> _buy(PeyvShopItem item) async {
    if (_busy) return;
    if (_balance < item.cost) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.notEnoughPeyv),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.shopOffline),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _busy = true;
      _busyItem = item.key;
    });
    HapticFeedback.lightImpact();
    final ok = await FirestoreService.instance.spendPeyv(
      uid: uid,
      amount: item.cost,
      reason: 'shop_${item.key.name}',
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _balance -= item.cost;
        _busy = false;
        _busyItem = null;
      });
      HapticFeedback.mediumImpact();
      widget.onItemPurchased?.call(item.key);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.purchased(
              L.current == AppLocale.tr ? item.trLabel : item.kuLabel)),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _busy = false;
        _busyItem = null;
      });
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.purchaseFailed),
          backgroundColor: const Color(0xFFD32F2F),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTr = L.current == AppLocale.tr;
    final bg = isDark ? const Color(0xFF101824) : const Color(0xFFFFFFFF);
    final fg = isDark ? Colors.white : const Color(0xFF18242C);
    final muted = fg.withValues(alpha: 0.6);
    final divider = fg.withValues(alpha: 0.08);

    // Gösterilecek item'lar: enabledItems'taki + showLocked ise seviye-kilitli olanlar.
    final visible = _allItems.where((i) {
      if (widget.enabledItems.contains(i.key)) return true;
      if (!widget.showLocked) return false;
      // showLocked modunda, seviye-bağımlı olanları kilitli olarak göster
      return _isLevelGated(i.key);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header: balance + close
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00BFA5).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.savings_rounded,
                          color: Color(0xFF00BFA5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isTr ? 'Peyv Mağazası' : 'Suka Peyv',
                              style: TextStyle(
                                  color: fg,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          Text(
                              isTr
                                  ? 'Bakiye: $_balance Peyv'
                                  : 'Hesab: $_balance Peyv',
                              style: TextStyle(color: muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: muted),
                    ),
                  ],
                ),
              ),
              Divider(color: divider, height: 1),
              // Items
              Expanded(
                child: visible.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            isTr
                                ? 'Şu an satın alınabilir item yok.'
                                : 'Niha tiştek nayê kirîn.',
                            style: TextStyle(color: muted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        itemCount: visible.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = visible[i];
                          final locked = _isLocked(item.key);
                          final affordable = _balance >= item.cost;
                          final isBusy = _busyItem == item.key;
                          return _ShopItemTile(
                            item: item,
                            affordable: affordable,
                            isBusy: isBusy,
                            locked: locked,
                            unlockLevel:
                                locked ? _unlockLevelFor(item.key) : null,
                            fg: fg,
                            isDark: isDark,
                            isTr: isTr,
                            onBuy: () => _buy(item),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShopItemTile extends StatelessWidget {
  final PeyvShopItem item;
  final bool affordable;
  final bool isBusy;
  final bool locked;
  final int? unlockLevel;
  final Color fg;
  final bool isDark;
  final bool isTr;
  final VoidCallback onBuy;
  const _ShopItemTile({
    required this.item,
    required this.affordable,
    required this.isBusy,
    required this.locked,
    required this.unlockLevel,
    required this.fg,
    required this.isDark,
    required this.isTr,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final label = isTr ? item.trLabel : item.kuLabel;
    final desc = isTr ? item.trDesc : item.kuDesc;
    final tileColor = isDark
        ? Colors.white.withValues(alpha: 0.04)
        : Colors.black.withValues(alpha: 0.03);
    final muted = fg.withValues(alpha: 0.65);
    final tappable = !locked && affordable && !isBusy;
    final fadedAccent = locked ? muted : item.color;

    return Material(
      color: tileColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: tappable ? onBuy : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:
                          fadedAccent.withValues(alpha: locked ? 0.08 : 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: fadedAccent, size: 22),
                  ),
                  if (locked)
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFF424242),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: isDark
                                  ? const Color(0xFF101824)
                                  : Colors.white,
                              width: 2),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.white, size: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: locked ? muted : fg,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                        if (locked && unlockLevel != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFB300)
                                  .withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFFFB300)
                                      .withValues(alpha: 0.4),
                                  width: 0.8),
                            ),
                            child: Text(
                              'L$unlockLevel',
                              style: const TextStyle(
                                color: Color(0xFFB8860B),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: TextStyle(
                            color:
                                muted.withValues(alpha: locked ? 0.5 : muted.a),
                            fontSize: 11.5,
                            height: 1.3)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: ElevatedButton(
                  onPressed: tappable ? onBuy : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (tappable)
                        ? const Color(0xFF00BFA5)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: isBusy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          '${item.cost}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
