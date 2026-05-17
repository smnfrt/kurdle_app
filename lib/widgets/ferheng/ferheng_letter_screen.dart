import 'package:flutter/material.dart';
import 'package:kurdle_app/controllers/ferheng_controller.dart';
import 'package:kurdle_app/models/ferheng_entry.dart';
import 'package:kurdle_app/services/ferheng_service.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_design.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_detail_screen.dart';
import 'package:kurdle_app/widgets/ferheng/ferheng_entry_tile.dart';

class FerhengLetterScreen extends StatefulWidget {
  final String letter;
  final FerhengController controller;

  const FerhengLetterScreen({
    super.key,
    required this.letter,
    required this.controller,
  });

  @override
  State<FerhengLetterScreen> createState() => _FerhengLetterScreenState();
}

class _FerhengLetterScreenState extends State<FerhengLetterScreen> {
  bool _loading = true;
  List<FerhengEntry> _entries = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await FerhengService.instance.byLetter(widget.letter);
      if (!mounted) return;
      setState(() {
        _entries = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FerhengDesign.bg,
      appBar: AppBar(
        backgroundColor: FerhengDesign.bg,
        foregroundColor: FerhengDesign.textPrimary,
        elevation: 0,
        title: Text('${widget.letter} —'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FerhengDesign.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: FerhengDesign.caption),
                  ),
                )
              : _entries.isEmpty
                  ? Center(
                      child: Text('—',
                          style: TextStyle(color: FerhengDesign.textFaint)),
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
