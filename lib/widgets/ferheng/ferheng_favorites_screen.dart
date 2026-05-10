import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/ferheng_service.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_detail_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_entry_tile.dart';

class FerhengFavoritesScreen extends StatefulWidget {
  final FerhengController controller;
  const FerhengFavoritesScreen({super.key, required this.controller});

  @override
  State<FerhengFavoritesScreen> createState() => _FerhengFavoritesScreenState();
}

class _FerhengFavoritesScreenState extends State<FerhengFavoritesScreen> {
  bool _loading = true;
  List<FerhengEntry> _entries = const [];
  String? _signedOutMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _signedOutMessage = L.needSignIn;
      });
      return;
    }
    final ids = await FerhengService.instance.listFavoriteIds(uid);
    final entries = <FerhengEntry>[];
    for (final id in ids) {
      final e = await FerhengService.instance.getOrFallback(id);
      if (e != null) entries.add(e);
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
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
        title: Text(L.ferhengFavorites),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FerhengDesign.primary))
          : _signedOutMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_signedOutMessage!,
                        style: FerhengDesign.bodyMd, textAlign: TextAlign.center),
                  ),
                )
              : _entries.isEmpty
                  ? Center(
                      child: Text(L.ferhengEmpty,
                          style: FerhengDesign.caption),
                    )
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, i) => FerhengEntryTile(
                        entry: _entries[i],
                        displayLanguage: widget.controller.definitionLanguage,
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(
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
