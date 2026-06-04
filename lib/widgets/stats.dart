import 'dart:math';
import 'package:flutter/material.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/domain.dart' as domain;
import 'package:kurdle_app/services/stats_service.dart';
import 'package:kurdle_app/widgets/countdown.dart';
import 'package:share_plus/share_plus.dart';

class StatsWidget extends StatefulWidget {
  const StatsWidget(this._stats, this._settings, this._close, this._newGame, {super.key});

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
  int _getFlex(int number, int total) =>
      total == 0 ? 0 : (number / (number + (total - number)) * 10).ceil();

  Future<Stats> get _stats => Future.microtask(() => StatsService().loadStats());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _stats,
        builder: (BuildContext context, AsyncSnapshot<Stats> snapshot) {
          return Material(
            shadowColor: Colors.black12,
            child: BlockSemantics(
              blocking: true,
              child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                      width: 500,
                      height: 520,
                      child: Stack(children: [
                        Positioned(
                            top: 0,
                            left: 0,
                            child: SizedBox(
                              width: 410,
                              height: 520,
                              child: Column(children: [
                                Row(
                                  children: [
                                    const Spacer(),
                                    TextButton(
                                        onPressed: () =>
                                            widget.close(domain.Dialog.stats, show: false),
                                        child: Semantics(
                                            label: 'tap to close Stats',
                                            child: const ExcludeSemantics(
                                                excluding: true,
                                                child: Text("X", style: TextStyle(fontSize: 20)))))
                                  ],
                                ),
                                const Center(
                                    child: Text(
                                  "İSTATİSTİK",
                                  style: TextStyle(
                                    fontSize: 18,
                                  ),
                                )),
                                // XP/Peyv ödül tablosu (deneme sayısına göre)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 10, 10, 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF538d4e)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFF538d4e)
                                            .withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text('🎯 Ödüller',
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                        SizedBox(height: 4),
                                        _RewardLine(
                                            tries: '1 deneme',
                                            xp: 170,
                                            peyv: 17,
                                            tag: ' (en iyi)'),
                                        _RewardLine(
                                            tries: '2 deneme',
                                            xp: 150,
                                            peyv: 15),
                                        _RewardLine(
                                            tries: '3 deneme',
                                            xp: 130,
                                            peyv: 13),
                                        _RewardLine(
                                            tries: '4 deneme',
                                            xp: 110,
                                            peyv: 11),
                                        _RewardLine(
                                            tries: '5 deneme',
                                            xp: 90,
                                            peyv: 9),
                                        _RewardLine(
                                            tries: '6 deneme',
                                            xp: 70,
                                            peyv: 7),
                                        _RewardLine(
                                            tries: 'Kayıp',
                                            xp: 10,
                                            peyv: 0),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 20, 10, 5),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, right: 4),
                                        child: Column(
                                          children: [
                                            Semantics(
                                              label: 'Games played is ${widget.stats.played}',
                                              child: ExcludeSemantics(
                                                excluding: true,
                                                child: Text(
                                                  widget.stats.played.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 36,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const ExcludeSemantics(
                                              child: Text(
                                                "Played",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, right: 4),
                                        child: Column(
                                          children: [
                                            Semantics(
                                              label: 'Win percentage is ${widget.stats.percentWon}',
                                              child: ExcludeSemantics(
                                                excluding: true,
                                                child: Text(
                                                  widget.stats.percentWon.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 36,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const ExcludeSemantics(
                                              child: Text(
                                                "Win %",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, right: 4),
                                        child: Column(
                                          children: [
                                            Semantics(
                                              label:
                                                  'Current streak is ${widget.stats.streak.current}',
                                              child: ExcludeSemantics(
                                                excluding: true,
                                                child: Text(
                                                  widget.stats.streak.current.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 36,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            ExcludeSemantics(
                                              child: Column(children: const [
                                                Center(
                                                    child: Text(
                                                  "Current",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                )),
                                                Center(
                                                    child: Text(
                                                  "Streak",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ))
                                              ]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4, right: 4),
                                        child: Column(
                                          children: [
                                            Semantics(
                                              label: 'Max Streak is ${widget.stats.streak.max}',
                                              child: ExcludeSemantics(
                                                excluding: true,
                                                child: Text(
                                                  widget.stats.streak.max.toString(),
                                                  style: const TextStyle(
                                                    fontSize: 36,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            ExcludeSemantics(
                                              child: Column(children: const [
                                                Center(
                                                    child: Text(
                                                  "Max",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                )),
                                                Center(
                                                    child: Text(
                                                  "Streak",
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ))
                                              ]),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(top: 20),
                                  child: Center(
                                      child: Text(
                                    "GUESS DISTRIBUTION",
                                    style: TextStyle(
                                      fontSize: 18,
                                    ),
                                  )),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(40, 10, 40, 10),
                                  child: _guessDistribution(),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            children: [
                                              const Center(
                                                  child: Text(
                                                "NEXT FLUTTERDLE",
                                                style: TextStyle(
                                                  fontSize: 16,
                                                ),
                                              )),
                                              CountdownWidget(widget.newGame),
                                            ],
                                          ),
                                        ),
                                        VerticalDivider(
                                          color: Theme.of(context).colorScheme.secondary,
                                          width: 2,
                                          indent: 2,
                                          endIndent: 2,
                                          thickness: 2,
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 16, left: 16),
                                            child: Semantics(
                                              label: 'Share button',
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor: widget.settings.isHighContrast
                                                        ? Colors.orange
                                                        : Colors.green),
                                                onPressed: () {
                                                  var guesses = widget.stats.lastGuess == -1
                                                      ? 'X'
                                                      : widget.stats.lastGuess;
                                                  Share.share(
                                                      'Peyvok ${widget.stats.gameNumber} $guesses/6\n${widget.stats.lastBoard}',
                                                      subject: 'Peyvok $guesses/6');
                                                },
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: const [
                                                    Text('SHARE',
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                        )),
                                                    SizedBox(
                                                      width: 5,
                                                    ),
                                                    Icon(
                                                      Icons.share,
                                                      color: Colors.white,
                                                      size: 24.0,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              ]),
                            ))
                      ]))),
            ),
          );
        });
  }

  Widget _guessDistribution() {
    if (widget.stats.played == 0) {
      return const Center(
          child: Text(
        "No Data",
        style: TextStyle(fontSize: 20),
      ));
    }

    var maxGuess = widget.stats.guessDistribution.reduce(max);
    var children = <Widget>[];

    for (var i = 0; i < widget.stats.guessDistribution.length; i++) {
      children.add(_statRow(i + 1, widget.stats.guessDistribution[i], maxGuess,
          isCurrent: (i + 1) == widget.stats.lastGuess));
    }
    return Column(children: children);
  }

  Widget _statRow(int rowNumber, int completed, int total, {bool isCurrent = false}) {
    return Semantics(
      label:
          'Guess $rowNumber has ${isCurrent ? 'most recently ' : ''}won $completed time${completed == 1 ? '' : 's'}',
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 3.0),
              child: ExcludeSemantics(
                excluding: true,
                child: Text(
                  rowNumber.toString(),
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            Expanded(
              flex: _getFlex(completed, total),
              child: Container(
                  color: isCurrent
                      ? widget.settings.isHighContrast
                          ? Colors.orange
                          : Colors.green
                      : const Color.fromARGB(255, 90, 87, 87),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: ExcludeSemantics(
                      excluding: true,
                      child: Text(
                        completed.toString(),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )),
            ),
            Expanded(
              flex: _getFlex(total - completed, total),
              child: Container(),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              tries,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$xp XP',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB8860B),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (peyv > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF00BFA5).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+$peyv Peyv',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF00786A),
                ),
              ),
            ),
          if (tag.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.withValues(alpha: 0.8),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
