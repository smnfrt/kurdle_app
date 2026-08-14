import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/domain.dart' as domain;
import 'package:kurdle_app/services/stats_service.dart';
import 'package:kurdle_app/widgets/countdown.dart';
import 'package:share_plus/share_plus.dart';

const _kStatsBg = Color(0xFF071018);
const _kStatsSurface = Color(0xFF121E2D);
const _kStatsSurface2 = Color(0xFF172437);
const _kStatsPrimary = Color(0xFF3FBE6F);
const _kStatsGold = Color(0xFFFFD27A);
const _kStatsBlue = Color(0xFF6CC0F5);

class StatsWidget extends StatefulWidget {
  const StatsWidget(
    this._stats,
    this._settings,
    this._close,
    this._newGame, {
    super.key,
  });

  final Stats _stats;
  final Settings _settings;
  final void Function(domain.Dialog, {bool show}) _close;
  final Function _newGame;

  Stats get stats => _stats;
  Settings get settings => _settings;

  Function(domain.Dialog, {bool show}) get close => _close;
  Function get newGame => _newGame;

  @override
  State<StatefulWidget> createState() => _StatsState();
}

class _StatsState extends State<StatsWidget> {
  Future<Stats> get _stats =>
      Future.microtask(() => StatsService().loadStats());

  Color get _accent =>
      widget.settings.isHighContrast ? Colors.orange : _kStatsPrimary;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Stats>(
      future: _stats,
      builder: (context, snapshot) {
        return Material(
          color: Colors.black.withValues(alpha: 0.42),
          child: BlockSemantics(
            blocking: true,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  margin: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _kStatsBg,
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.40),
                        blurRadius: 28,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 16),
                          _buildSummary(),
                          const SizedBox(height: 14),
                          _RewardPanel(accent: _accent),
                          const SizedBox(height: 14),
                          _buildDistribution(),
                          const SizedBox(height: 14),
                          _buildFooterActions(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    final guesses =
        widget.stats.lastGuess == -1 ? 'X' : widget.stats.lastGuess.toString();

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient:
                LinearGradient(colors: [_accent, const Color(0xFF1B5E20)]),
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.insights_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'İSTATİSTİK',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Leyar ${widget.stats.gameNumber} • $guesses/6',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          label: 'tap to close Stats',
          child: IconButton(
            onPressed: () => widget.close(domain.Dialog.stats, show: false),
            icon: const Icon(Icons.close_rounded),
            color: Colors.white.withValues(alpha: 0.68),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final items = [
      _StatMetric('Oyun', widget.stats.played.toString(), _kStatsBlue),
      _StatMetric('Kazanma', '%${widget.stats.percentWon}', _accent),
      _StatMetric(
          'Seri', widget.stats.streak.current.toString(), Colors.orange),
      _StatMetric('En iyi', widget.stats.streak.max.toString(), _kStatsGold),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _MetricCard(metric: items[i])),
        ],
      ],
    );
  }

  Widget _buildDistribution() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kStatsSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: _accent, size: 18),
              const SizedBox(width: 8),
              const Text(
                'DENEME DAĞILIMI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.stats.played == 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Henüz veri yok',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            )
          else
            ..._distributionRows(),
        ],
      ),
    );
  }

  List<Widget> _distributionRows() {
    final maxGuess = max(1, widget.stats.guessDistribution.reduce(max));
    return [
      for (var i = 0; i < widget.stats.guessDistribution.length; i++)
        _DistributionRow(
          rowNumber: i + 1,
          completed: widget.stats.guessDistribution[i],
          maxGuess: maxGuess,
          accent: _accent,
          isCurrent: i + 1 == widget.stats.lastGuess,
        ),
    ];
  }

  Widget _buildFooterActions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kStatsSurface2, _kStatsSurface],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIRADAKİ OYUN',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                CountdownWidget(widget.newGame),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Semantics(
            label: 'Share button',
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                final guesses =
                    widget.stats.lastGuess == -1 ? 'X' : widget.stats.lastGuess;
                Share.share(
                  'Leyar ${widget.stats.gameNumber} $guesses/6\n${widget.stats.lastBoard}',
                  subject: 'Leyar $guesses/6',
                );
              },
              icon: const Icon(Icons.share_rounded, size: 19),
              label: const Text(
                'PAYLAŞ',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatMetric {
  final String label;
  final String value;
  final Color color;

  const _StatMetric(this.label, this.value, this.color);
}

class _MetricCard extends StatelessWidget {
  final _StatMetric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: _kStatsSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: metric.color.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          Text(
            metric.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: metric.color,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.52),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionRow extends StatelessWidget {
  final int rowNumber;
  final int completed;
  final int maxGuess;
  final bool isCurrent;
  final Color accent;

  const _DistributionRow({
    required this.rowNumber,
    required this.completed,
    required this.maxGuess,
    required this.isCurrent,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final value = completed / maxGuess;
    final color = isCurrent ? accent : Colors.white.withValues(alpha: 0.30);

    return Semantics(
      label:
          'Guess $rowNumber has ${isCurrent ? 'most recently ' : ''}won $completed time${completed == 1 ? '' : 's'}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: ExcludeSemantics(
                child: Text(
                  '$rowNumber',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width =
                      max(30.0, constraints.maxWidth * value.clamp(0.0, 1.0));
                  return Stack(
                    children: [
                      Container(
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        width: width,
                        height: 26,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCurrent
                                ? Colors.white.withValues(alpha: 0.18)
                                : Colors.transparent,
                          ),
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '$completed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardPanel extends StatelessWidget {
  final Color accent;

  const _RewardPanel({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.16),
            _kStatsGold.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: _kStatsGold, size: 18),
              SizedBox(width: 8),
              Text(
                'ÖDÜLLER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _RewardLine(tries: '1 deneme', xp: 170, peyv: 17, tag: 'en iyi'),
          _RewardLine(tries: '2 deneme', xp: 150, peyv: 15),
          _RewardLine(tries: '3 deneme', xp: 130, peyv: 13),
          _RewardLine(tries: '4 deneme', xp: 110, peyv: 11),
          _RewardLine(tries: '5 deneme', xp: 90, peyv: 9),
          _RewardLine(tries: '6 deneme', xp: 70, peyv: 7),
          _RewardLine(tries: 'Kayıp', xp: 10, peyv: 0),
        ],
      ),
    );
  }
}

class _RewardLine extends StatelessWidget {
  final String tries;
  final int xp;
  final int peyv;
  final String tag;

  const _RewardLine({
    required this.tries,
    required this.xp,
    required this.peyv,
    this.tag = '',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tries,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _RewardPill(text: '+$xp XP', color: _kStatsGold),
          const SizedBox(width: 6),
          if (peyv > 0) _RewardPill(text: '+$peyv Peyv', color: _kStatsPrimary),
          if (tag.isNotEmpty) ...[
            const SizedBox(width: 6),
            Text(
              tag,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.46),
                fontSize: 10,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RewardPill extends StatelessWidget {
  final String text;
  final Color color;

  const _RewardPill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
