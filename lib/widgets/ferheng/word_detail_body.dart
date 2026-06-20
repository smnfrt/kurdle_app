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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
          _InfoPanel(
              child: Text(entry.displayMeaning(language),
                  style: FerhengDesign.bodyMd))
        else
          ..._buildDefinitions(visibleDefs, usingFallback, language),
        if (entry.etymology.isNotEmpty) ...[
          const SizedBox(height: 20),
          _SectionTitle(L.ferhengEtymology),
          const SizedBox(height: 6),
          _InfoPanel(child: Text(entry.etymology, style: FerhengDesign.bodyMd)),
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
                      labelStyle: TextStyle(color: FerhengDesign.textPrimary),
                      side: BorderSide(color: FerhengDesign.border),
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
                      labelStyle: TextStyle(color: FerhengDesign.textMuted),
                      side: BorderSide(color: FerhengDesign.border),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: FerhengDesign.isDark
              ? const [Color(0xFF1A2A40), Color(0xFF111D2C)]
              : const [Color(0xFFFFFFFF), Color(0xFFF4EFE5)],
        ),
        borderRadius: FerhengDesign.radLg,
        border: Border.all(color: FerhengDesign.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: FerhengDesign.isDark ? 0.18 : 0.05,
            ),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [FerhengDesign.primary, FerhengDesign.primaryGlow],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.headword.isNotEmpty
                  ? entry.headword.characters.first.toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.headword, style: FerhengDesign.titleLg),
                const SizedBox(height: 6),
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
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: FerhengDesign.accentGold
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: FerhengDesign.accentGold
                                  .withValues(alpha: 0.22),
                            ),
                          ),
                          child: Text(p,
                              style: FerhengDesign.caption.copyWith(
                                color: FerhengDesign.accentGold,
                                fontWeight: FontWeight.w800,
                              )),
                        )),
                  ],
                ),
              ],
            ),
          ),
          if (onFavoriteToggle != null)
            IconButton.filledTonal(
              tooltip: isFavorite ? L.ferhengRemovedFav : L.ferhengAddedFav,
              onPressed: onFavoriteToggle,
              icon: Icon(
                isFavorite
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
              ),
              color: FerhengDesign.primary,
            ),
        ],
      ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FerhengDesign.surface,
        borderRadius: FerhengDesign.radLg,
        border: Border.all(color: FerhengDesign.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: FerhengDesign.bodyMd,
              children: [
                TextSpan(
                  text: '$index. ',
                  style: TextStyle(
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
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final Widget child;

  const _InfoPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FerhengDesign.surface,
        borderRadius: FerhengDesign.radLg,
        border: Border.all(color: FerhengDesign.border),
      ),
      child: child,
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
        borderRadius: FerhengDesign.radLg,
        border: Border.all(color: FerhengDesign.border),
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
