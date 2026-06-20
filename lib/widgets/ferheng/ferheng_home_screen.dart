import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/ferheng_service.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_detail_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_favorites_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_learning_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_letter_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_search_screen.dart';

/// Ferheng ana ekranı: arama bar, Word of the Day, alfabe ızgarası, recent
/// searches, favoriler kısayolu, öğrenme modu girişi, attribution footer.
class FerhengHomeScreen extends StatefulWidget {
  const FerhengHomeScreen({super.key});

  @override
  State<FerhengHomeScreen> createState() => _FerhengHomeScreenState();
}

class _FerhengHomeScreenState extends State<FerhengHomeScreen> {
  late final FerhengController _controller;
  FerhengEntry? _wotd;
  bool _wotdLoading = true;
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    _controller = FerhengController();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Bundle yüklemesi (196k+ entry, ilk açılışta birkaç saniye sürer).
    // Idempotent — sonraki açılışlarda hızlıca döner.
    await FerhengService.instance.init();
    final wotd = await FerhengService.instance.getWordOfTheDay();
    final recent = await FerhengService.instance.recentSearches();
    if (!mounted) return;
    setState(() {
      _wotd = wotd;
      _wotdLoading = false;
      _recent = recent;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(String word) {
    Navigator.of(context).push(
      appRoute(FerhengDetailScreen(word: word, controller: _controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: FerhengDesign.textPrimary,
        title: _FerhengTitle(),
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton.filledTonal(
            tooltip: L.ferhengFavorites,
            icon: const Icon(Icons.bookmark_rounded),
            color: FerhengDesign.primary,
            onPressed: () => Navigator.of(context).push(
              appRoute(FerhengFavoritesScreen(controller: _controller)),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: FerhengDesign.pageGradient,
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              sliver: SliverList.list(
                children: [
                  _SearchBar(controller: _controller),
                  const SizedBox(height: 16),
                  _WotdCard(entry: _wotd, loading: _wotdLoading, onTap: _open),
                  const SizedBox(height: 20),
                  _SectionTitle(L.current == AppLocale.tr
                      ? 'Alfabe ile gez'
                      : 'Bi alfabe geriyê'),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: _AlphabetSliverGrid(onLetterTap: (letter) {
                Navigator.of(context).push(
                  appRoute(FerhengLetterScreen(
                    letter: letter,
                    controller: _controller,
                  )),
                );
              }),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverList.list(
                children: [
                  _LearnShortcut(onTap: () {
                    Navigator.of(context).push(
                      appRoute(FerhengLearningScreen(controller: _controller)),
                    );
                  }),
                  if (_recent.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle(L.ferhengRecent),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _recent
                          .map((w) => ActionChip(
                                label: Text(w),
                                backgroundColor: FerhengDesign.surface,
                                labelStyle:
                                    TextStyle(color: FerhengDesign.textPrimary),
                                side: BorderSide(color: FerhengDesign.border),
                                onPressed: () => _open(w),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    L.ferhengAttribution,
                    style: FerhengDesign.caption
                        .copyWith(color: FerhengDesign.textFaint),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FerhengTitle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [FerhengDesign.primary, FerhengDesign.primaryGlow],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: FerhengDesign.primary.withValues(alpha: 0.24),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(Icons.menu_book_rounded,
              color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L.ferheng,
              style: TextStyle(
                color: FerhengDesign.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              L.current == AppLocale.tr ? 'Kelime hazinesi' : 'Xezîneya peyvan',
              style: TextStyle(
                color: FerhengDesign.textFaint,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  final FerhengController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: FerhengDesign.radLg,
      child: InkWell(
        borderRadius: FerhengDesign.radLg,
        onTap: () => Navigator.of(context).push(
          appRoute(FerhengSearchScreen(controller: controller)),
        ),
        child: Ink(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: FerhengDesign.surface,
            borderRadius: FerhengDesign.radLg,
            border: Border.all(color: FerhengDesign.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: FerhengDesign.isDark ? 0.18 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: FerhengDesign.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.search_rounded,
                    color: FerhengDesign.primary, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  L.ferhengSearchHint,
                  style: FerhengDesign.bodyMd
                      .copyWith(color: FerhengDesign.textFaint),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: FerhengDesign.textFaint, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _WotdCard extends StatelessWidget {
  final FerhengEntry? entry;
  final bool loading;
  final ValueChanged<String> onTap;

  const _WotdCard({
    required this.entry,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardDecoration = BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1A6A3C), Color(0xFF3FBE6F), Color(0xFFFFD27A)],
      ),
      borderRadius: FerhengDesign.radLg,
      boxShadow: [
        BoxShadow(
          color: FerhengDesign.primary.withValues(alpha: 0.20),
          blurRadius: 22,
          offset: const Offset(0, 12),
        ),
      ],
    );
    // Loading/empty durumlarında tıklanabilir gerek yok
    if (loading) {
      return Container(
        decoration: cardDecoration,
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white)),
        ),
      );
    }
    if (entry == null) {
      return Container(
        decoration: cardDecoration,
        padding: const EdgeInsets.all(20),
        child: Text(L.ferhengEmpty, style: FerhengDesign.bodyMd),
      );
    }
    // Tüm kart tappable — sadece headword text değil
    return Material(
      color: Colors.transparent,
      borderRadius: FerhengDesign.radLg,
      child: Ink(
        decoration: cardDecoration,
        child: InkWell(
          borderRadius: FerhengDesign.radLg,
          onTap: () => onTap(entry!.normalized),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22)),
                      ),
                      child: Text(
                        L.ferhengWotd.toUpperCase(),
                        style: FerhengDesign.caption.copyWith(
                          color: Colors.white,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.auto_awesome_rounded,
                        color: Colors.white, size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  entry!.headword,
                  style: FerhengDesign.titleLg.copyWith(fontSize: 32),
                ),
                const SizedBox(height: 6),
                Text(
                  entry!.displayMeaning(L.current),
                  style: FerhengDesign.bodyMd.copyWith(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlphabetSliverGrid extends StatelessWidget {
  final ValueChanged<String> onLetterTap;
  const _AlphabetSliverGrid({required this.onLetterTap});

  @override
  Widget build(BuildContext context) {
    return SliverGrid.builder(
      itemCount: kKurmanjiAlphabet.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (_, index) {
        final letter = kKurmanjiAlphabet[index];
        return _LetterButton(
          letter: letter,
          onTap: () => onLetterTap(letter),
        );
      },
    );
  }
}

class _LetterButton extends StatelessWidget {
  final String letter;
  final VoidCallback onTap;
  const _LetterButton({required this.letter, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FerhengDesign.surface,
      borderRadius: FerhengDesign.radSm,
      child: InkWell(
        onTap: onTap,
        borderRadius: FerhengDesign.radSm,
        child: Center(
          child: Text(
            letter,
            style: TextStyle(
              color: FerhengDesign.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _LearnShortcut extends StatelessWidget {
  final VoidCallback onTap;
  const _LearnShortcut({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: FerhengDesign.radLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: FerhengDesign.radLg,
        child: Ink(
          decoration: BoxDecoration(
            color: FerhengDesign.surface,
            borderRadius: FerhengDesign.radLg,
            border: Border.all(color: FerhengDesign.border),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: FerhengDesign.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.school_rounded,
                    color: FerhengDesign.primary, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(L.ferhengLearn, style: FerhengDesign.titleMd),
              ),
              Icon(Icons.chevron_right_rounded, color: FerhengDesign.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: FerhengDesign.caption.copyWith(
          color: FerhengDesign.textFaint,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      );
}
