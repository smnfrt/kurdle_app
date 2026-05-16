import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:kurdle_app/domain.dart';
import 'package:kurdle_app/domain.dart' as domain;
import 'package:kurdle_app/game.dart';
import 'package:kurdle_app/widgets/board.dart';
import 'package:kurdle_app/widgets/how_to.dart';
import 'package:kurdle_app/widgets/keyboard.dart';
import 'package:kurdle_app/widgets/settings.dart';
import 'package:kurdle_app/widgets/stats.dart';

class WordleGameScreen extends StatefulWidget {
  const WordleGameScreen({super.key});

  @override
  State<WordleGameScreen> createState() => _WordleGameScreenState();
}

class _WordleGameScreenState extends State<WordleGameScreen> {
  final Kurdle _game = Kurdle();
  final StreamController<Settings> _streamController = StreamController.broadcast();
  Future<bool> _initialized = Future<bool>.value(false);
  domain.Dialog _currentDialog = domain.Dialog.none;

  @override
  void initState() {
    super.initState();

    _streamController.stream.listen((settings) {
      if (_game.settings.isDarkMode != settings.isDarkMode) {
        _game.settings.isDarkMode = settings.isDarkMode;
        _game.persist();
      } else {
        _game.updateKeyboardLayout();
        _game.persist();
      }
    });

    _initialized = _game.init().then((value) {
      _streamController.add(_game.settings);
      return value;
    });
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  void _onKeyPressed(String val) {
    if (_game.context.remainingTries == 0 || _game.isEvaluating) return;
    setState(() {
      _game.evaluateTurn(val);
      if (_game.context.turnResult == TurnResult.unsuccessful) {
        var index = (_game.context.remainingTries - Kurdle.totalTries).abs();
        _game.shakeKeys[index].currentState?.forward();
        _game.isEvaluating = false;
      } else if (_game.context.turnResult == TurnResult.successful) {
        for (var i = 0; i < _game.context.attempt.length; i++) {
          var offset = i + ((Kurdle.totalTries - _game.context.remainingTries) * Kurdle.rowLength);
          Timer(Duration(milliseconds: i * 200), () {
            setState(() {
              _game.context.board.tiles[offset] = _game.context.attempt[i];
            });
          });
        }
        final didWin = _game.didWin(_game.context.attempt);
        final delay = didWin ? 4 : 2;
        if (didWin) {
          Timer(const Duration(seconds: 2), () {
            for (var i = 0; i < _game.context.attempt.length; i++) {
              var offset = i + ((Kurdle.totalTries - _game.context.remainingTries) * Kurdle.rowLength);
              Timer(Duration(milliseconds: i * 200), () {
                setState(() {
                  _game.bounceKeys[offset].currentState?.forward();
                });
              });
            }
          });
        }
        Timer(Duration(seconds: delay), () {
          setState(() {
            _game.updateAfterSuccessfulGuess().then((_) => setState(() {}));
            _resetMessage();
            _game.isEvaluating = false;
          });
        });
      } else {
        _game.isEvaluating = false;
      }
    });
    _resetMessage();
  }

  void _newGame() {
    setState(() {
      _game.init();
    });
    _resetMessage();
  }

  void _resetMessage() {
    if (_game.context.message.isNotEmpty) {
      Timer(const Duration(seconds: 2), () {
        setState(() {
          _game.context.message = '';
        });
        if (_game.context.remainingTries == 0) {
          Timer(const Duration(milliseconds: 500), () {
            _setDialog(domain.Dialog.stats);
          });
        }
      });
    }
  }

  void _setDialog(domain.Dialog dialog, {bool show = true}) {
    setState(() {
      _currentDialog = show ? dialog : domain.Dialog.none;
      SemanticsService.announce(
          '${show ? 'Showing' : 'Closing'} ${_currentDialog.name}', TextDirection.ltr);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialized,
      builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Peyvok')),
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          );
        }

        _resetMessage();

        return Stack(children: [
          Scaffold(
            appBar: AppBar(
              leading: Padding(
                padding: const EdgeInsets.only(left: 16, right: 20),
                child: GestureDetector(
                  onTap: () => _setDialog(domain.Dialog.help),
                  child: Semantics(
                    label: 'Yardım',
                    child: const Icon(Icons.help_outline, size: 26),
                  ),
                ),
              ),
              title: const Text('Peyvok'),
              centerTitle: true,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16),
                  child: GestureDetector(
                    onTap: () => _setDialog(domain.Dialog.stats),
                    child: Semantics(
                      label: 'İstatistikler',
                      child: const Icon(Icons.leaderboard, size: 26),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: GestureDetector(
                    onTap: () => _setDialog(domain.Dialog.settings),
                    child: Semantics(
                      label: 'Ayarlar',
                      child: const Icon(Icons.settings, size: 26),
                    ),
                  ),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(children: [
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: 400,
                        height: 670,
                        child: Stack(children: [
                          Positioned(
                            top: 0,
                            left: 25,
                            child: BoardWidget(
                              _game,
                              Kurdle.rowLength,
                              _game.shakeKeys,
                              _game.bounceKeys,
                              _game.settings,
                            ),
                          ),
                          Positioned(
                            top: 470,
                            left: 0,
                            child: Keyboard(
                              _game.context.keys,
                              _game.settings,
                              _onKeyPressed,
                            ),
                          ),
                          if (_currentDialog == domain.Dialog.stats) ...[
                            Positioned(
                              top: 50,
                              left: 0,
                              child: StatsWidget(
                                _game.stats,
                                _game.settings,
                                _setDialog,
                                _newGame,
                              ),
                            ),
                          ],
                          if (_currentDialog == domain.Dialog.settings) ...[
                            Positioned(
                              top: 50,
                              left: 0,
                              child: SettingsWidget(
                                _setDialog,
                                _streamController,
                                _game.settings,
                                _game.packageInfo,
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ),
                ]);
              },
            ),
          ),
          if (_currentDialog == domain.Dialog.help) ...[
            SafeArea(child: HowTo(_setDialog, _game.settings)),
          ],
        ]);
      },
    );
  }
}
