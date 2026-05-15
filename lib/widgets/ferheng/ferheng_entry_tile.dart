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
      child: InkWell(
        onTap: onTap,
        borderRadius: FerhengDesign.radMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: FerhengDesign.divider, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(entry.headword, style: FerhengDesign.titleMd),
                        if (entry.pos.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            entry.pos.first,
                            style: FerhengDesign.caption.copyWith(
                              fontStyle: FontStyle.italic,
                              color: FerhengDesign.textFaint,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (gloss.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        gloss,
                        style: FerhengDesign.bodyMd.copyWith(
                          color: FerhengDesign.textMuted,
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
