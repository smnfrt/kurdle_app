import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/ferheng_service.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_detail_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_entry_tile.dart';

/// Kategori listesi → tıklayınca o kategorideki kelimeler.
class FerhengCategoryScreen extends StatelessWidget {
  final FerhengController controller;
  const FerhengCategoryScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final categories = FerhengService.instance.categories();
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        title: Text(L.ferhengCategories),
        elevation: 0,
      ),
      body: ListView.separated(
        itemCount: categories.length,
        separatorBuilder: (_, __) => const Divider(
          color: FerhengDesign.divider,
          height: 1,
        ),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isTr = L.current == AppLocale.tr;
          final label = (isTr ? cat['label_tr'] : cat['label_kmr']) ?? '';
          return ListTile(
            title: Text(label, style: FerhengDesign.bodyMd),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: FerhengDesign.textFaint),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _CategoryListScreen(
                categoryId: cat['id']!,
                title: label,
                controller: controller,
              ),
            )),
          );
        },
      ),
    );
  }
}

class _CategoryListScreen extends StatefulWidget {
  final String categoryId;
  final String title;
  final FerhengController controller;

  const _CategoryListScreen({
    required this.categoryId,
    required this.title,
    required this.controller,
  });

  @override
  State<_CategoryListScreen> createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<_CategoryListScreen> {
  bool _loading = true;
  List<FerhengEntry> _entries = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results =
        await FerhengService.instance.byCategory(widget.categoryId);
    if (!mounted) return;
    setState(() {
      _entries = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        title: Text(widget.title),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FerhengDesign.primary))
          : _entries.isEmpty
              ? Center(
                  child: Text(L.ferhengEmpty, style: FerhengDesign.caption),
                )
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, i) => FerhengEntryTile(
                    entry: _entries[i],
                    displayLanguage: widget.controller.definitionLanguage,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FerhengDetailScreen(
                        word: _entries[i].normalized,
                        controller: widget.controller,
                      ),
                    )),
                  ),
                ),
    );
  }
}
