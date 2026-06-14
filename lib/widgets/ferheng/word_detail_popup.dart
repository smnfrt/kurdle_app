import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/services/achievement_service.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_detail_screen.dart';
import 'package:kurdle_app/widgets/ferheng/word_detail_body.dart';

/// Oyun içi tap → bottom sheet detay popup'ı.
/// Detay ekranıyla aynı `WordDetailBody` widget'ını kullanır.
class WordDetailPopup extends StatefulWidget {
  final String word;
  const WordDetailPopup({super.key, required this.word});

  /// Yardımcı: doğrudan showModalBottomSheet çağırır.
  static Future<void> show(BuildContext context, String word) {
    return showAppModalBottomSheet(
      context: context,
      backgroundColor: FerhengDesign.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => WordDetailPopup(word: word),
    );
  }

  @override
  State<WordDetailPopup> createState() => _WordDetailPopupState();
}

class _WordDetailPopupState extends State<WordDetailPopup> {
  late final FerhengController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FerhengController()..openEntry(widget.word);
    AchievementService.instance.onFerhengEntryViewed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.72;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppSheetDragHandle(
              color: FerhengDesign.textFaint,
              width: 36,
              margin: const EdgeInsets.only(top: 8, bottom: 4),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  final c = _controller;
                  if (c.status == FerhengStatus.loading) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: FerhengDesign.primary));
                  }
                  final entry = c.currentEntry;
                  if (entry == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(L.ferhengNoDefinition,
                            style: FerhengDesign.bodyMd),
                      ),
                    );
                  }
                  return WordDetailBody(
                    entry: entry,
                    language: c.definitionLanguage,
                    onLanguageChanged: c.setDefinitionLanguage,
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Navigator.of(context).push(
                          appRoute(FerhengDetailScreen(
                            word: widget.word,
                            controller: FerhengController(),
                          )),
                        );
                      });
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: FerhengDesign.surfaceAlt,
                      foregroundColor: FerhengDesign.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: const RoundedRectangleBorder(
                          borderRadius: FerhengDesign.radMd),
                    ),
                    child: Text(_openFullText(L.current)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _openFullText(AppLocale locale) =>
      locale == AppLocale.tr ? 'Tam ekranda aç' : 'Bi tevahî veke';
}
