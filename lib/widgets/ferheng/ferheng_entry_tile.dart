import 'package:flutter/material.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';

/// Ferheng listelerinde kullanılan ortak satır widget'ı.
class FerhengEntryTile extends StatelessWidget {
  final FerhengEntry entry;
  final AppLocale displayLanguage;
  final VoidCallback? onTap;
  final Widget? trailing;

  const FerhengEntryTile({
    super.key,
    required this.entry,
    required this.displayLanguage,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final gloss = entry.displayMeaning(displayLanguage);
    return Material(
      color: Colors.transparent,
      borderRadius: FerhengDesign.radLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: FerhengDesign.radLg,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: FerhengDesign.surface,
            borderRadius: FerhengDesign.radLg,
            border: Border.all(color: FerhengDesign.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: FerhengDesign.isDark ? 0.14 : 0.04,
                ),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: FerhengDesign.primary.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  entry.headword.isNotEmpty
                      ? entry.headword.characters.first.toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: FerhengDesign.primary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.headword,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FerhengDesign.titleMd,
                          ),
                        ),
                        if (entry.pos.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: FerhengDesign.accentGold
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: FerhengDesign.accentGold
                                    .withValues(alpha: 0.22),
                              ),
                            ),
                            child: Text(
                              entry.pos.first,
                              style: FerhengDesign.caption.copyWith(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: FerhengDesign.accentGold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (gloss.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        gloss,
                        style: FerhengDesign.bodyMd.copyWith(
                          color: FerhengDesign.textMuted,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ] else
                Icon(Icons.chevron_right_rounded,
                    color: FerhengDesign.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
