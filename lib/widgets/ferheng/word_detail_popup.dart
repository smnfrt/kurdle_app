import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
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
    return showModalBottomSheet(
      context: context,
      backgroundColor: FerhengDesign.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: FerhengDesign.textFaint,
              borderRadius: BorderRadius.circular(2),
            ),
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
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FerhengDetailScreen(
                        word: widget.word,
                        controller: FerhengController(),
                      ),
                    ));
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
    );
  }

  String _openFullText(AppLocale locale) =>
      locale == AppLocale.tr ? 'Tam ekranda aç' : 'Bi tevahî veke';
}
