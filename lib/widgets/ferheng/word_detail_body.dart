import 'package:flutter/material.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';

/// Bir ferheng girdisinin tüm detayını gösterir. Hem tam sayfada hem de
/// bottom sheet pop-up'ında aynı body kullanılır — ekran tutarlılığı için.
class WordDetailBody extends StatelessWidget {
  final FerhengEntry entry;
  final AppLocale language;
  final ValueChanged<AppLocale>? onLanguageChanged;
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;

  const WordDetailBody({
    super.key,
    required this.entry,
    required this.language,
    this.onLanguageChanged,
    this.onFavoriteToggle,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final defs = entry.definitionsFor(language);
    final fallback = entry
        .definitionsFor(language == AppLocale.tr ? AppLocale.ku : AppLocale.tr);
    final visibleDefs = defs.isNotEmpty ? defs : fallback;
    final usingFallback = defs.isEmpty && fallback.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        _Header(
          entry: entry,
          isFavorite: isFavorite,
          onFavoriteToggle: onFavoriteToggle,
        ),
        const SizedBox(height: 12),
        // Dil toggle yalnızca her iki dilde de tanım varsa anlamlı olur.
        // Şu an çoğu entry sadece Türkçe — toggle gizleniyor (gelecekte
        // Kurmancî tanımlar eklenirse otomatik açılır).
        if (onLanguageChanged != null &&
            entry.definitionsKmr.isNotEmpty &&
            entry.definitionsTr.isNotEmpty) ...[
          _LanguageToggle(
            current: language,
            onChanged: onLanguageChanged!,
          ),
          const SizedBox(height: 16),
        ] else
          const SizedBox(height: 4),
        if (visibleDefs.isEmpty)
          Text(entry.displayMeaning(language), style: FerhengDesign.bodyMd)
        else
          ..._buildDefinitions(visibleDefs, usingFallback, language),
        if (entry.etymology.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(L.ferhengEtymology),
          const SizedBox(height: 6),
          Text(entry.etymology, style: FerhengDesign.bodyMd),
        ],
        if (entry.related.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(L.ferhengRelated),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.related
                .map((w) => Chip(
                      label: Text(w),
                      backgroundColor: FerhengDesign.surfaceAlt,
                      labelStyle:
                          const TextStyle(color: FerhengDesign.textPrimary),
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ],
        if (entry.categories.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(L.ferhengCategories),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: entry.categories
                .map((c) => Chip(
                      label: Text(c),
                      backgroundColor: FerhengDesign.surface,
                      labelStyle:
                          const TextStyle(color: FerhengDesign.textMuted),
                      side: BorderSide.none,
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        _AttributionFooter(entry: entry),
      ],
    );
  }

  List<Widget> _buildDefinitions(
    List<FerhengDefinition> defs,
    bool fallback,
    AppLocale lang,
  ) {
    return [
      if (fallback)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            lang == AppLocale.tr
                ? '(${L.missingTurkishMeaning} — Kürtçe gösteriliyor)'
                : '(${L.missingKurdishMeaning} — Tirkî tê nîşandan)',
            style: FerhengDesign.caption.copyWith(
              color: FerhengDesign.textFaint,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      for (var i = 0; i < defs.length; i++) ...[
        _DefinitionItem(index: i + 1, def: defs[i]),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  final FerhengEntry entry;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const _Header({
    required this.entry,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.headword, style: FerhengDesign.titleLg),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (entry.ipa.isNotEmpty)
                    Text('/${entry.ipa}/',
                        style: FerhengDesign.caption.copyWith(
                          fontStyle: FontStyle.italic,
                          color: FerhengDesign.textMuted,
                        )),
                  ...entry.pos.map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: FerhengDesign.surfaceAlt,
                          borderRadius: FerhengDesign.radSm,
                        ),
                        child: Text(p,
                            style: FerhengDesign.caption.copyWith(
                              color: FerhengDesign.textMuted,
                            )),
                      )),
                ],
              ),
            ],
          ),
        ),
        if (onFavoriteToggle != null)
          IconButton(
            tooltip: isFavorite ? L.ferhengRemovedFav : L.ferhengAddedFav,
            onPressed: onFavoriteToggle,
            icon: Icon(
              isFavorite
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              color: FerhengDesign.primary,
            ),
          ),
      ],
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  final AppLocale current;
  final ValueChanged<AppLocale> onChanged;

  const _LanguageToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FerhengDesign.surfaceAlt,
        borderRadius: FerhengDesign.radMd,
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _LanguagePill(
            label: L.ferhengLangToggleKmr,
            active: current == AppLocale.ku,
            onTap: () => onChanged(AppLocale.ku),
          ),
          _LanguagePill(
            label: L.ferhengLangToggleTr,
            active: current == AppLocale.tr,
            onTap: () => onChanged(AppLocale.tr),
          ),
        ],
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LanguagePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? FerhengDesign.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : FerhengDesign.textMuted,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _DefinitionItem extends StatelessWidget {
  final int index;
  final FerhengDefinition def;

  const _DefinitionItem({required this.index, required this.def});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: FerhengDesign.bodyMd,
            children: [
              TextSpan(
                text: '$index. ',
                style: const TextStyle(
                  color: FerhengDesign.textFaint,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: def.gloss),
            ],
          ),
        ),
        if (def.examples.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: def.examples
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '"${e.text}"',
                              style: FerhengDesign.bodyMd.copyWith(
                                fontStyle: FontStyle.italic,
                                color: FerhengDesign.textMuted,
                              ),
                            ),
                            if (e.translation.isNotEmpty)
                              Text(
                                e.translation,
                                style: FerhengDesign.caption,
                              ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
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

class _AttributionFooter extends StatelessWidget {
  final FerhengEntry entry;
  const _AttributionFooter({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FerhengDesign.surface,
        borderRadius: FerhengDesign.radMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L.ferhengAttribution,
            style:
                FerhengDesign.caption.copyWith(color: FerhengDesign.textFaint),
          ),
          if (entry.sourceUrl.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.sourceUrl,
              style: FerhengDesign.caption.copyWith(
                color: FerhengDesign.textFaint,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
