import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_detail_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_entry_tile.dart';

class FerhengSearchScreen extends StatefulWidget {
  final FerhengController controller;
  final String? initialQuery;
  const FerhengSearchScreen({
    super.key,
    required this.controller,
    this.initialQuery,
  });

  @override
  State<FerhengSearchScreen> createState() => _FerhengSearchScreenState();
}

class _FerhengSearchScreenState extends State<FerhengSearchScreen> {
  late final TextEditingController _input;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initialQuery ?? '');
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => widget.controller.setQuery(widget.initialQuery!));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        elevation: 0,
        title: TextField(
          controller: _input,
          autofocus: widget.initialQuery == null,
          onChanged: widget.controller.setQuery,
          style: FerhengDesign.bodyMd,
          decoration: InputDecoration(
            hintText: L.ferhengSearchHint,
            hintStyle: FerhengDesign.caption,
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _input.clear();
              widget.controller.clearSearch();
            },
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          if (c.query.trim().isEmpty) {
            return Center(
              child: Text(L.ferhengEmpty, style: FerhengDesign.caption),
            );
          }
          if (c.status == FerhengStatus.loading) {
            return const Center(
                child: CircularProgressIndicator(color: FerhengDesign.primary));
          }
          if (c.searchResults.isEmpty) {
            return Center(
              child: Text(L.ferhengNoDefinition,
                  style: FerhengDesign.bodyMd),
            );
          }
          return ListView.builder(
            itemCount: c.searchResults.length,
            itemBuilder: (context, i) {
              final entry = c.searchResults[i];
              return FerhengEntryTile(
                entry: entry,
                displayLanguage: c.definitionLanguage,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FerhengDetailScreen(
                    word: entry.normalized,
                    controller: widget.controller,
                  ),
                )),
              );
            },
          );
        },
      ),
    );
  }
}
