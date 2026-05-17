import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_category_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_flashcard_screen.dart';

/// Öğrenme modunun giriş hub'ı: kategoriler ve flashcard.
class FerhengLearningScreen extends StatelessWidget {
  final FerhengController controller;
  const FerhengLearningScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        title: Text(L.ferhengLearn),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _LearnCard(
            icon: Icons.style_rounded,
            label: L.ferhengLearn,
            subtitle: L.current == AppLocale.tr
                ? '10 kart — kelime ve anlamını eşleştir'
                : '10 kart — peyv û wateya wê li hev bîne',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const FerhengFlashcardScreen(),
            )),
          ),
          const SizedBox(height: 12),
          _LearnCard(
            icon: Icons.category_rounded,
            label: L.ferhengCategories,
            subtitle: L.current == AppLocale.tr
                ? 'Konuya göre keşfet — hayvanlar, vücut, doğa...'
                : 'Li gor mijaran kêş bike — heywan, beden, xweza...',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  FerhengCategoryScreen(controller: controller),
            )),
          ),
        ],
      ),
    );
  }
}

class _LearnCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _LearnCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FerhengDesign.surface,
      borderRadius: FerhengDesign.radLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: FerhengDesign.radLg,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: FerhengDesign.primary.withValues(alpha: 0.15),
                  borderRadius: FerhengDesign.radMd,
                ),
                child: Icon(icon, color: FerhengDesign.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: FerhengDesign.titleMd),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: FerhengDesign.caption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: FerhengDesign.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
