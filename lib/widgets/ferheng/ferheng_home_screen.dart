import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          FerhengDetailScreen(word: word, controller: _controller),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        title: Text(L.ferheng),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: L.ferhengFavorites,
            icon: const Icon(Icons.bookmark_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  FerhengFavoritesScreen(controller: _controller),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SearchBar(controller: _controller),
          const SizedBox(height: 16),
          _WotdCard(entry: _wotd, loading: _wotdLoading, onTap: _open),
          const SizedBox(height: 20),
          _SectionTitle(L.current == AppLocale.tr
              ? 'Alfabe ile gez'
              : 'Bi alfabe geriyê'),
          const SizedBox(height: 8),
          _AlphabetGrid(onLetterTap: (letter) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FerhengLetterScreen(
                letter: letter,
                controller: _controller,
              ),
            ));
          }),
          const SizedBox(height: 20),
          _LearnShortcut(onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  FerhengLearningScreen(controller: _controller),
            ));
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
                            const TextStyle(color: FerhengDesign.textPrimary),
                        side: BorderSide.none,
                        onPressed: () => _open(w),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            L.ferhengAttribution,
            style: FerhengDesign.caption.copyWith(
                color: FerhengDesign.textFaint),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final FerhengController controller;
  const _SearchBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FerhengDesign.surface,
      borderRadius: FerhengDesign.radMd,
      child: InkWell(
        borderRadius: FerhengDesign.radMd,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => FerhengSearchScreen(controller: controller),
        )),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: FerhengDesign.textFaint, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  L.ferhengSearchHint,
                  style: FerhengDesign.bodyMd
                      .copyWith(color: FerhengDesign.textFaint),
                ),
              ),
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
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF66E093)],
        ),
        borderRadius: FerhengDesign.radLg,
      ),
      padding: const EdgeInsets.all(20),
      child: loading
          ? const Center(
              child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)),
            )
          : entry == null
              ? Text(L.ferhengEmpty, style: FerhengDesign.bodyMd)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L.ferhengWotd.toUpperCase(),
                      style: FerhengDesign.caption.copyWith(
                        color: Colors.white70,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => onTap(entry!.normalized),
                      child: Text(
                        entry!.headword,
                        style: FerhengDesign.titleLg
                            .copyWith(fontSize: 32),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry!.displayGloss(L.current),
                      style: FerhengDesign.bodyMd
                          .copyWith(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
    );
  }
}

class _AlphabetGrid extends StatelessWidget {
  final ValueChanged<String> onLetterTap;
  const _AlphabetGrid({required this.onLetterTap});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: kKurmanjiAlphabet
          .map((letter) => _LetterButton(
                letter: letter,
                onTap: () => onLetterTap(letter),
              ))
          .toList(),
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
            style: const TextStyle(
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
      color: FerhengDesign.surface,
      borderRadius: FerhengDesign.radMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: FerhengDesign.radMd,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.school_rounded,
                  color: FerhengDesign.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(L.ferhengLearn,
                    style: FerhengDesign.titleMd),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: FerhengDesign.textFaint),
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
