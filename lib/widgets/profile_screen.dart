import 'package:flutter/material.dart';
import 'package:kurdle_app/models/achievement.dart';
import 'package:kurdle_app/services/achievement_service.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/auth_service.dart';
import 'package:kurdle_app/services/firebase_service.dart';
import 'package:kurdle_app/services/firestore_service.dart';

const _kBg = Color(0xFF0F1923);
const _kSurface = Color(0xFF1A2535);
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
  const titles = [
    'Yeni Başlayan',
    'Çırak',
    'Öğrenci',
    'Usta Aday',
    'Usta',
    'İleri Usta',
    'Uzman',
    'Şampiyon',
    'Efsane',
    'Peyvok Ustası',
  ];
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
  const ProfileScreen({Key? key}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
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
            stats: _profile!.stats,
            createdAt: _profile!.createdAt,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('İsim güncellendi'),
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
      backgroundColor: _kBg,
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A2535), Color(0xFF0F1923)],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black38, blurRadius: 12, offset: Offset(0, 3))
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
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white54, size: 16),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('Profilim',
                    style: TextStyle(
                        color: Colors.white,
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
                        _buildAvatarSection(user),
                        const SizedBox(height: 20),
                        if (_profile != null) ...[
                          _buildXpCard(),
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

  Widget _buildAvatarSection(user) {
    final isAnon = AuthService.instance.isAnonymous;
    final photoUrl = user?.photoURL as String?;
    final name = _profile?.displayName ?? user?.displayName ?? 'Oyuncu';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF1B5E20)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                    color: _kPrimary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4))
              ],
            ),
            child: photoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Image.network(photoUrl, fit: BoxFit.cover),
                  )
                : Center(
                    child: Text(initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold)),
                  ),
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
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    cursorColor: _kPrimary,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: _kPrimary.withOpacity(0.5)),
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
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white54, size: 20),
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
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ),
                if (isAnon) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: const Text('Misafir',
                        style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3)),
                  ),
                ],
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Icon(Icons.edit_rounded,
                      color: Colors.white.withOpacity(0.35), size: 16),
                ),
              ],
            ),

          const SizedBox(height: 6),
          Text(
            isAnon ? 'Anonim Kullanıcı' : (user?.email ?? ''),
            style:
                TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
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
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kGold.withOpacity(0.2)),
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
                  color: _kGold.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kGold.withOpacity(0.3)),
                ),
                child: Text('Seviye $level',
                    style: const TextStyle(
                        color: _kGold,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Text(_levelTitle(level),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 13)),
              const Spacer(),
              Text('$xp XP',
                  style: const TextStyle(
                      color: _kGold,
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
                backgroundColor: Colors.white.withOpacity(0.08),
                valueColor: const AlwaysStoppedAnimation(_kGold),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Sonraki seviyeye $toNext XP',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 11)),
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
        label: 'Oyun',
        value: '${s.played}'
      ),
      (
        icon: Icons.emoji_events_rounded,
        color: _kPrimary,
        label: 'Kazanma',
        value: '%$winRate'
      ),
      (
        icon: Icons.local_fire_department,
        color: const Color(0xFFFF7043),
        label: 'Seri',
        value: '${s.streak}'
      ),
      (
        icon: Icons.star_rounded,
        color: _kGold,
        label: 'En Yüksek',
        value: '${s.highScore}'
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('İstatistikler',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
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
                              color: item.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(item.icon, color: item.color, size: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(item.value,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text(item.label,
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.35),
                                  fontSize: 10)),
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
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Rozetler',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
              const Spacer(),
              Text('$unlocked/${defs.length}',
                  style: const TextStyle(
                      color: _kGold,
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
        color: _kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Text(
        'Firebase bağlantısı yok — profil bilgileri görüntülenemiyor.',
        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _AchievementRow extends StatelessWidget {
  final AchievementDef def;
  final AchievementState state;
  final bool isTr;

  const _AchievementRow({
    required this.def,
    required this.state,
    required this.isTr,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (state.progress / def.target).clamp(0.0, 1.0);
    final color = state.unlocked ? def.tierColor : Colors.white38;
    final desc = state.unlocked
        ? (isTr ? 'Kazanıldı' : 'Hat bidestxistin')
        : def.desc(isTr);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: state.unlocked
            ? def.tierColor.withOpacity(0.10)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: state.unlocked
              ? def.tierColor.withOpacity(0.35)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(state.unlocked ? 0.18 : 0.08),
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
                    color: state.unlocked ? Colors.white : Colors.white70,
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
                    color: Colors.white.withOpacity(0.38),
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
                      backgroundColor: Colors.white.withOpacity(0.08),
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
              color: state.unlocked ? def.tierColor : Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
