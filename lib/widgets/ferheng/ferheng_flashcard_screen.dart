import 'package:flutter/material.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/achievement_service.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/ferheng_service.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';

/// Basit flashcard turu: 10 kart, flip → know/don't know, sonunda özet.
class FerhengFlashcardScreen extends StatefulWidget {
  const FerhengFlashcardScreen({super.key});

  @override
  State<FerhengFlashcardScreen> createState() => _FerhengFlashcardScreenState();
}

class _FerhengFlashcardScreenState extends State<FerhengFlashcardScreen> {
  bool _loading = true;
  List<FerhengEntry> _cards = const [];
  int _index = 0;
  int _correct = 0;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cards = await FerhengService.instance.getRandomForFlashcard();
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  void _answer(bool known) {
    final completed = _index + 1 >= _cards.length;
    setState(() {
      if (known) _correct++;
      _index++;
      _flipped = false;
    });
    if (completed) {
      AchievementService.instance.onFlashcardCompleted();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: FerhengDesign.bg,
        body: Center(
            child: CircularProgressIndicator(color: FerhengDesign.primary)),
      );
    }
    if (_cards.isEmpty) {
      return Scaffold(
        backgroundColor: FerhengDesign.bg,
        appBar: _appBar(context),
        body: Center(
          child: Text(L.ferhengEmpty, style: FerhengDesign.caption),
        ),
      );
    }
    if (_index >= _cards.length) {
      return Scaffold(
        backgroundColor: FerhengDesign.bg,
        appBar: _appBar(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration_rounded,
                    size: 64, color: FerhengDesign.primary),
                const SizedBox(height: 16),
                Text(
                  L.ferhengFlashcardResult(_correct, _cards.length),
                  style: FerhengDesign.titleMd,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FerhengDesign.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final card = _cards[_index];
    final lang = L.current;
    final answer = card.displayGloss(lang);

    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: _appBar(context),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _index / _cards.length,
              color: FerhengDesign.primary,
              backgroundColor: FerhengDesign.surfaceAlt,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _flipped = !_flipped),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _flipped
                        ? FerhengDesign.surface
                        : FerhengDesign.surfaceAlt,
                    borderRadius: FerhengDesign.radLg,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _flipped ? (answer.isEmpty ? '—' : answer) : card.headword,
                    style: FerhengDesign.titleLg.copyWith(
                      fontSize: _flipped ? 22 : 36,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_flipped)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _answer(false),
                      child: Text(L.ferhengFlashcardUnknown),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FerhengDesign.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => _answer(true),
                      child: Text(L.ferhengFlashcardKnown),
                    ),
                  ),
                ],
              )
            else
              Text(
                L.current == AppLocale.tr
                    ? 'Karta dokun ve cevabı gör'
                    : 'Li kartê bide, bersivê bibîne',
                style: FerhengDesign.caption,
              ),
          ],
        ),
      ),
    );
  }

  AppBar _appBar(BuildContext context) => AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        elevation: 0,
        title: Text(L.ferhengLearn),
      );
}
