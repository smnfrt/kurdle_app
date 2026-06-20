import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/route_transitions.dart';
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
        backgroundColor: Colors.transparent,
        foregroundColor: FerhengDesign.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        title: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: FerhengDesign.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: FerhengDesign.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded,
                  color: FerhengDesign.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _input,
                  autofocus: widget.initialQuery == null,
                  onChanged: widget.controller.setQuery,
                  style: FerhengDesign.bodyMd,
                  cursorColor: FerhengDesign.primary,
                  decoration: InputDecoration(
                    hintText: L.ferhengSearchHint,
                    hintStyle: FerhengDesign.caption
                        .copyWith(color: FerhengDesign.textFaint),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: FerhengDesign.pageGradient,
          ),
        ),
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final c = widget.controller;
            if (c.query.trim().isEmpty) {
              return _EmptySearchState(
                icon: Icons.manage_search_rounded,
                text: L.ferhengSearchHint,
              );
            }
            if (c.status == FerhengStatus.loading) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: FerhengDesign.primary));
            }
            if (c.searchResults.isEmpty) {
              return _EmptySearchState(
                icon: Icons.search_off_rounded,
                text: L.ferhengNoDefinition,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: c.searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final entry = c.searchResults[i];
                return FerhengEntryTile(
                  entry: entry,
                  displayLanguage: c.definitionLanguage,
                  onTap: () => Navigator.of(context).push(
                    appRoute(FerhengDetailScreen(
                      word: entry.normalized,
                      controller: widget.controller,
                    )),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptySearchState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: FerhengDesign.surface,
          borderRadius: FerhengDesign.radLg,
          border: Border.all(color: FerhengDesign.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: FerhengDesign.primary, size: 34),
            const SizedBox(height: 12),
            Text(
              text,
              style: FerhengDesign.bodyMd.copyWith(
                color: FerhengDesign.textMuted,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
