import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kurdle_app/models/achievement.dart';
import 'package:kurdle_app/services/achievement_service.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';
import 'package:kurdle_app/services/level_rewards.dart';
import 'package:kurdle_app/widgets/peyv_shop_sheet.dart';

const _kBgDark = Color(0xFF0F1923);
const _kBgLight = Color(0xFFF6F1E8);
const _kSurfaceDark = Color(0xFF1A2535);
const _kSurfaceLight = Color(0xFFFFFFFF);
const _kOnLight = Color(0xFF18242C);
const _kPrimary = Color(0xFF4CAF50);
const _kGold = Color(0xFFFFD700);

// XP → seviye eşikleri
const _levelThresholds = [
  0,
  200,
  500,
  1000,
  2000,
  3500,
  5500,
  8000,
  11000,
  15000
];

String _levelTitle(int level) {
  final titles = L.levelTitles;
  final idx = (level - 1).clamp(0, titles.length - 1);
  return titles[idx];
}

double _xpProgress(int xp, int level) {
  final lo = level <= _levelThresholds.length
      ? _levelThresholds[level - 1]
      : _levelThresholds.last;
  final hi = level < _levelThresholds.length
      ? _levelThresholds[level]
      : _levelThresholds.last + 5000;
  if (hi <= lo) return 1.0;
  return ((xp - lo) / (hi - lo)).clamp(0.0, 1.0);
}

int _xpToNextLevel(int xp, int level) {
  final hi = level < _levelThresholds.length
      ? _levelThresholds[level]
      : _levelThresholds.last + 5000;
  return (hi - xp).clamp(0, 99999);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  Map<String, AchievementState> _achievementStates = const {};
  bool _loading = true;
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _nameCtrl;
  StreamSubscription<UserProfile?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _load();
    _subscribeProfile();
  }

  void _subscribeProfile() {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) return;
    _profileSub?.cancel();
    _profileSub = FirestoreService.instance.profileStream(uid).listen((p) {
      if (!mounted || p == null) return;
      setState(() {
        _profile = p;
        // Re-sync name controller if not currently editing
        if (!_editing) {
          _nameCtrl.text = p.displayName;
        }
      });
    });
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? _kBgDark : _kBgLight;
  Color get _surface => _isDark ? _kSurfaceDark : _kSurfaceLight;
  Color get _onBg => _isDark ? Colors.white : _kOnLight;
  Color _onBgA(double a) => _onBg.withValues(alpha: a);
  Color get _surfaceBorder => _isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.08);
  Color get _inputFill => _isDark
      ? Colors.white.withValues(alpha: 0.07)
      : Colors.black.withValues(alpha: 0.04);

  Future<void> _load() async {
    // E-posta doğrulama durumunu tazele (kullanıcı mail linkine başka cihazdan
    // tıklamış olabilir).
    unawaited(
      AuthService.instance.reloadAndCheckVerified().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {}),
    );
    final achievements = await AchievementService.instance.getAllStates();
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null || !FirebaseService.isAvailable) {
      if (mounted) {
        setState(() {
          _achievementStates = achievements;
          _loading = false;
        });
      }
      return;
    }
    final profile = await FirestoreService.instance.getProfile(uid);
    if (mounted) {
      setState(() {
        _profile = profile;
        _achievementStates = achievements;
        _nameCtrl.text = profile?.displayName ??
            AuthService.instance.currentUser?.displayName ??
            '';
        _loading = false;
      });
    }
  }

  Future<void> _saveName() async {
    if (AuthService.instance.isAnonymous) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _saving = true);
    await FirestoreService.instance.updateDisplayName(uid, name);
    await AuthService.instance.currentUser?.updateDisplayName(name);
    if (mounted) {
      setState(() {
        _editing = false;
        _saving = false;
        if (_profile != null) {
          _profile = UserProfile(
            uid: _profile!.uid,
            displayName: name,
            email: _profile!.email,
            xp: _profile!.xp,
            level: _profile!.level,
            peyv: _profile!.peyv,
            stats: _profile!.stats,
            createdAt: _profile!.createdAt,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.nameUpdated),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final bottom = MediaQuery.of(context).padding.bottom;
    final user = AuthService.instance.currentUser;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // Header — theme-aware
          Container(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isDark
                    ? const [Color(0xFF1A2535), Color(0xFF0F1923)]
                    : const [Color(0xFFFFFFFF), Color(0xFFF1EADC)],
              ),
              border: _isDark
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black
                        .withValues(alpha: _isDark ? 0.38 : 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 3))
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isDark
                            ? Colors.white12
                            : Colors.black.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: _onBgA(0.55), size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                Text(L.profileTitle,
                    style: TextStyle(
                        color: _onBg,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // İçerik
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _kPrimary))
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, bottom + 24),
                    child: Column(
                      children: [
                        _buildVerifyBanner(user),
                        _buildAvatarSection(user),
                        const SizedBox(height: 20),
                        if (_profile != null) ...[
                          _buildXpCard(),
                          const SizedBox(height: 16),
                          _buildLevelRewardsCard(),
                          const SizedBox(height: 16),
                          _buildStatsCard(),
                          const SizedBox(height: 16),
                          _buildAchievementsCard(),
                        ] else ...[
                          _buildAchievementsCard(),
                          const SizedBox(height: 16),
                          _buildOfflineNotice(),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  bool _sendingVerify = false;

  Widget _buildVerifyBanner(user) {
    if (user == null) return const SizedBox.shrink();
    final isAnon = AuthService.instance.isAnonymous;
    if (isAnon) return const SizedBox.shrink();
    final email = (user.email as String?) ?? '';
    final verified = (user.emailVerified as bool?) ?? false;
    if (email.isEmpty || verified) return const SizedBox.shrink();

    const amber = Color(0xFFFFB300);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: _isDark ? 0.12 : 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_rounded,
              color: amber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E-postanı doğrula',
                  style: TextStyle(
                      color: _onBg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '$email adresine gönderilen bağlantıya tıkla.',
                  style:
                      TextStyle(color: _onBgA(0.7), fontSize: 11, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: amber,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: _sendingVerify ? null : _resendVerification,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                child: _sendingVerify
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Gönder',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openShop() async {
    if (_profile == null) return;
    await PeyvShopSheet.show(
      context: context,
      currentPeyv: _profile!.peyv,
      playerLevel: _profile!.level,
      // Profile bağlamında tüm item'ları göster; oyun-içi item'lar
      // (Enhance/Steal) burada satın alınamaz, sadece bilgilendirme amaçlı.
      // Wordle Hint / Daily Retry de bağlam dışı olduğu için satın
      // alma butonu aktif değil — kilitli görünür.
      enabledItems: const {},
      showLocked: true,
    );
  }

  Future<void> _resendVerification() async {
    setState(() => _sendingVerify = true);
    final err = await AuthService.instance.sendEmailVerification();
    if (!mounted) return;
    setState(() => _sendingVerify = false);
    final ok = err == null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Doğrulama maili gönderildi. Spam klasörünü de kontrol et.'
            : err),
        backgroundColor: ok ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildAvatarSection(user) {
    final isAnon = AuthService.instance.isAnonymous;
    final photoUrl = user?.photoURL as String?;
    final name =
        _profile?.displayName ?? user?.displayName ?? L.playerFallback;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _surfaceBorder),
        boxShadow: _isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // Avatar — seviye-bağımlı çerçeve
          _AvatarWithFrame(
            photoUrl: photoUrl,
            initial: initial,
            level: _profile?.level ?? 1,
          ),
          const SizedBox(height: 16),

          // İsim + düzenleme
          if (_editing)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    style: TextStyle(color: _onBg, fontSize: 16),
                    cursorColor: _kPrimary,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: _inputFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: _kPrimary.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _kPrimary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _saving ? null : _saveName,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _editing = false;
                    _nameCtrl.text = _profile?.displayName ?? '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.close_rounded,
                        color: _onBgA(0.5), size: 20),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _onBg,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                if (isAnon) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _onBgA(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _onBgA(0.18)),
                    ),
                    child: Text(L.guestBadge,
                        style: TextStyle(
                            color: _onBgA(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3)),
                  ),
                ],
                if (!isAnon) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _editing = true),
                    child: Icon(Icons.edit_rounded,
                        color: _onBgA(0.4), size: 16),
                  ),
                ],
              ],
            ),

          const SizedBox(height: 6),
          Text(
            isAnon ? L.anonymousUser : (user?.email ?? ''),
            style: TextStyle(color: _onBgA(0.45), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildXpCard() {
    final xp = _profile!.xp;
    final level = _profile!.level;
    final progress = _xpProgress(xp, level);
    final toNext = _xpToNextLevel(xp, level);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withValues(alpha: 0.2)),
        boxShadow: _isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _kGold.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                ),
                child: Text(L.levelLabel(level),
                    style: TextStyle(
                        color: _isDark ? _kGold : const Color(0xFF8A6D00),
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text(_levelTitle(level),
                  style: TextStyle(color: _onBgA(0.65), fontSize: 13)),
              const Spacer(),
              Text('$xp XP',
                  style: TextStyle(
                      color: _isDark ? _kGold : const Color(0xFF8A6D00),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: _onBgA(0.10),
                valueColor: const AlwaysStoppedAnimation(_kGold),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(L.xpToNext(toNext),
                    style: TextStyle(color: _onBgA(0.4), fontSize: 11)),
              ),
              GestureDetector(
                onTap: _openShop,
                child: _PeyvChip(
                  amount: _profile!.peyv,
                  onBg: _onBg,
                  isDark: _isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLevelRewardsCard() {
    final currentLevel = _profile?.level ?? 1;
    final isTr = L.current == AppLocale.tr;
    final unlocked =
        kLevelRewards.where((r) => r.level <= currentLevel).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _surfaceBorder),
        boxShadow: _isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isTr ? 'Seviye Ödülleri' : 'Xelatên Ast',
                style: TextStyle(
                  color: _onBgA(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                '$unlocked/${kLevelRewards.length}',
                style: const TextStyle(
                  color: Color(0xFF4CAF50),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...kLevelRewards.map((r) => _LevelRewardTile(
                reward: r,
                achieved: currentLevel >= r.level,
                onBg: _onBg,
                isDark: _isDark,
                isTr: isTr,
              )),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final s = _profile!.stats;
    final winRate = s.played > 0 ? (s.won / s.played * 100).round() : 0;

    final items = [
      (
        icon: Icons.sports_esports_rounded,
        color: const Color(0xFF64B5F6),
        label: L.statGames,
        value: '${s.played}'
      ),
      (
        icon: Icons.emoji_events_rounded,
        color: _kPrimary,
        label: L.statWinRate,
        value: '%$winRate'
      ),
      (
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF7043),
        label: L.statStreak,
        value: '${s.streak}'
      ),
      (
        icon: Icons.star_rounded,
        color: _kGold,
        label: L.statHighScore,
        value: '${s.highScore}'
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _surfaceBorder),
        boxShadow: _isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L.statsHeading,
              style: TextStyle(
                  color: _onBgA(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 14),
          Row(
            children: items
                .map((item) => Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                Icon(item.icon, color: item.color, size: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(item.value,
                              style: TextStyle(
                                  color: _onBg,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(item.label,
                              style: TextStyle(
                                  color: _onBgA(0.45), fontSize: 10)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsCard() {
    final defs = AchievementService.definitions;
    final unlocked = defs
        .where((def) => _achievementStates[def.id]?.unlocked == true)
        .length;
    final isTr = L.current == AppLocale.tr;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _surfaceBorder),
        boxShadow: _isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(L.achievementsHeading,
                  style: TextStyle(
                      color: _onBgA(0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text('$unlocked/${defs.length}',
                  style: TextStyle(
                      color: _isDark ? _kGold : const Color(0xFF8A6D00),
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          ...defs.map((def) {
            final state =
                _achievementStates[def.id] ?? AchievementState(id: def.id);
            return _AchievementRow(
              def: def,
              state: state,
              isTr: isTr,
              isDark: _isDark,
              onBg: _onBg,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOfflineNotice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _surfaceBorder),
      ),
      child: Text(
        L.offlineProfile,
        style: TextStyle(color: _onBgA(0.5), fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  final AchievementDef def;
  final AchievementState state;
  final bool isTr;
  final bool isDark;
  final Color onBg;

  const _AchievementRow({
    required this.def,
    required this.state,
    required this.isTr,
    required this.isDark,
    required this.onBg,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (state.progress / def.target).clamp(0.0, 1.0);
    final lockedIconColor = onBg.withValues(alpha: 0.38);
    final color = state.unlocked ? def.tierColor : lockedIconColor;
    final desc = state.unlocked ? L.achievementUnlocked : def.desc(isTr);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: state.unlocked
            ? def.tierColor.withValues(alpha: 0.10)
            : onBg.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state.unlocked
              ? def.tierColor.withValues(alpha: 0.35)
              : onBg.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: state.unlocked ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              state.unlocked ? def.icon : Icons.lock_rounded,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  def.title(isTr),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        state.unlocked ? onBg : onBg.withValues(alpha: 0.78),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onBg.withValues(alpha: 0.45),
                    fontSize: 11.5,
                  ),
                ),
                if (!state.unlocked && def.target > 1) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: onBg.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation(def.tierColor),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            state.unlocked
                ? '✓'
                : '${state.progress.clamp(0, def.target)}/${def.target}',
            style: TextStyle(
              color:
                  state.unlocked ? def.tierColor : onBg.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRewardTile extends StatelessWidget {
  final LevelReward reward;
  final bool achieved;
  final Color onBg;
  final bool isDark;
  final bool isTr;
  const _LevelRewardTile({
    required this.reward,
    required this.achieved,
    required this.onBg,
    required this.isDark,
    required this.isTr,
  });

  @override
  Widget build(BuildContext context) {
    final title = isTr ? reward.trTitle : reward.kuTitle;
    final accent = achieved ? reward.accent : onBg.withValues(alpha: 0.3);
    final bgColor = isDark
        ? Colors.white.withValues(alpha: achieved ? 0.05 : 0.025)
        : Colors.black.withValues(alpha: achieved ? 0.03 : 0.015);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: achieved
              ? reward.accent.withValues(alpha: 0.4)
              : onBg.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Seviye rozeti
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: achieved ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              'L${reward.level}',
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // İkon
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: achieved ? 0.16 : 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(reward.icon, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: achieved ? onBg : onBg.withValues(alpha: 0.55),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            achieved
                ? Icons.check_circle_rounded
                : Icons.lock_outline_rounded,
            color: achieved
                ? const Color(0xFF4CAF50)
                : onBg.withValues(alpha: 0.3),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _AvatarWithFrame extends StatelessWidget {
  final String? photoUrl;
  final String initial;
  final int level;
  const _AvatarWithFrame({
    required this.photoUrl,
    required this.initial,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4CAF50);
    final frame = avatarFrameAtLevel(level);
    final frameColor = avatarFrameColor(frame);
    final hasFrame = frameColor != null;
    // Çerçeveli avatar daha küçük, halka boşluğu ekler
    final innerSize = hasFrame ? 76.0 : 80.0;
    final outerSize = hasFrame ? 92.0 : 80.0;

    final inner = Container(
      width: innerSize,
      height: innerSize,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: photoUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.network(photoUrl!, fit: BoxFit.cover),
            )
          : Center(
              child: Text(initial,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold)),
            ),
    );

    if (!hasFrame) return inner;

    // Çerçeve halkası: prestige için gradient + glow
    final isPrestige = frame == AvatarFrame.prestige;
    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(28),
        gradient: isPrestige
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  frameColor,
                  const Color(0xFFE1BEE7),
                  frameColor,
                ],
              )
            : null,
        color: isPrestige ? null : frameColor.withValues(alpha: 0.25),
        border: Border.all(color: frameColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: frameColor.withValues(alpha: 0.5),
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(5),
      child: inner,
    );
  }
}

class _PeyvChip extends StatelessWidget {
  final int amount;
  final Color onBg;
  final bool isDark;
  const _PeyvChip(
      {required this.amount, required this.onBg, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const peyvColor = Color(0xFF00BFA5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: peyvColor.withValues(alpha: isDark ? 0.14 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: peyvColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.savings_rounded, size: 13, color: peyvColor),
          const SizedBox(width: 4),
          Text(
            '$amount Peyv',
            style: TextStyle(
              color: isDark ? peyvColor : const Color(0xFF00786A),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
