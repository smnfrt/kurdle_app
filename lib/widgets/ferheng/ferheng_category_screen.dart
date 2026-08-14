import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/route_transitions.dart';
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
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        title: Text(L.ferhengCategories),
        elevation: 0,
      ),
      body: FutureBuilder<void>(
        future: FerhengService.instance.init(),
        builder: (context, snapshot) {
          final categories = FerhengService.instance.categories();
          if (snapshot.connectionState != ConnectionState.done &&
              categories.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: FerhengDesign.primary),
            );
          }
          return ListView.separated(
            itemCount: categories.length,
            separatorBuilder: (_, __) => Divider(
              color: FerhengDesign.divider,
              height: 1,
            ),
            itemBuilder: (context, i) {
              final cat = categories[i];
              final id = cat['id'] ?? '';
              final label = _localizedCategoryLabel(cat);
              return ListTile(
                title: Text(label, style: FerhengDesign.bodyMd),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: FerhengDesign.textFaint),
                onTap: () => Navigator.of(context).push(
                  appRoute(_CategoryListScreen(
                    categoryId: id,
                    title: label,
                    controller: controller,
                  )),
                ),
              );
            },
          );
        },
      ),
    );
  }

  static String _localizedCategoryLabel(Map<String, String> category) {
    final isTr = L.current == AppLocale.tr;
    final id = category['id'] ?? '';
    if (isTr) return category['label_tr'] ?? '';

    const kmrOverrides = <String, String>{
      'animals': 'Ajal',
      'animal': 'Ajal',
      'letters': 'Tîp',
      'letter': 'Tîp',
      'alphabet': 'Tîp',
      'abc': 'Tîp',
      'body': 'Endamên laş',
      'numbers': 'Hejmar',
      'colors': 'Reng',
      'verbs_common': 'Lêkerên berbelav',
      'religion_culture': 'Ol û çand',
    };
    return kmrOverrides[id] ?? category['label_kmr'] ?? '';
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
    final results = await FerhengService.instance.byCategory(widget.categoryId);
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
                    onTap: () => Navigator.of(context).push(
                      appRoute(FerhengDetailScreen(
                        word: _entries[i].normalized,
                        controller: widget.controller,
                      )),
                    ),
                  ),
                ),
    );
  }
}
