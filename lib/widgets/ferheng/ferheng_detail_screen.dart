import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/ferheng_service.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';
import 'package:kurdle_app/widgets/ferheng/word_detail_body.dart';

class FerhengDetailScreen extends StatefulWidget {
  final String word;
  final FerhengController controller;

  const FerhengDetailScreen({
    super.key,
    required this.word,
    required this.controller,
  });

  @override
  State<FerhengDetailScreen> createState() => _FerhengDetailScreenState();
}

class _FerhengDetailScreenState extends State<FerhengDetailScreen> {
  bool _isFavorite = false;
  bool _favBusy = false;

  @override
  void initState() {
    super.initState();
    widget.controller.openEntry(widget.word);
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final favs = await FerhengService.instance.listFavoriteIds(uid);
    if (!mounted) return;
    setState(() => _isFavorite = favs.contains(widget.word.toUpperCase()));
  }

  Future<void> _toggleFavorite() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _favBusy) return;
    setState(() => _favBusy = true);
    try {
      if (_isFavorite) {
        await FerhengService.instance.removeFavorite(uid, widget.word);
      } else {
        await FerhengService.instance.addFavorite(uid, widget.word);
      }
      if (!mounted) return;
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isFavorite ? L.ferhengAddedFav : L.ferhengRemovedFav),
        backgroundColor: FerhengDesign.surface,
        duration: const Duration(seconds: 2),
      ));
    } finally {
      if (mounted) setState(() => _favBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        title: Text(widget.word),
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          if (c.status == FerhengStatus.loading) {
            return const Center(
                child: CircularProgressIndicator(color: FerhengDesign.primary));
          }
          final entry = c.currentEntry;
          if (entry == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off_rounded,
                        size: 56, color: FerhengDesign.textFaint),
                    const SizedBox(height: 12),
                    Text(L.ferhengNoDefinition,
                        style: FerhengDesign.bodyMd, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          return WordDetailBody(
            entry: entry,
            language: c.definitionLanguage,
            onLanguageChanged: c.setDefinitionLanguage,
            isFavorite: _isFavorite,
            onFavoriteToggle: _favBusy ? null : _toggleFavorite,
          );
        },
      ),
    );
  }
}
