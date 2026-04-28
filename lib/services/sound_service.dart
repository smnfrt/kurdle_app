import 'package:audioplayers/audioplayers.dart';

enum SFX {
  tilePlace,
  wordValid,
  wordInvalid,
  aiTurn,
  scoreUp,
  win,
  lose,
  passTurn,
  tileExchange,
}

class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  bool _enabled = true;
  bool get enabled => _enabled;

  // Her ses için ayrı player — aynı anda birden fazla çalabilir
  final _players = <SFX, AudioPlayer>{};

  static const _files = {
    SFX.tilePlace:    'sounds/tile_place.wav',
    SFX.wordValid:    'sounds/word_valid.wav',
    SFX.wordInvalid:  'sounds/word_invalid.wav',
    SFX.aiTurn:       'sounds/ai_turn.wav',
    SFX.scoreUp:      'sounds/score_up.wav',
    SFX.win:          'sounds/win.wav',
    SFX.lose:         'sounds/lose.wav',
    SFX.passTurn:     'sounds/pass_turn.wav',
    SFX.tileExchange: 'sounds/tile_exchange.wav',
  };

  Future<void> init() async {
    for (final sfx in SFX.values) {
      _players[sfx] = AudioPlayer();
      await _players[sfx]!.setSource(AssetSource(_files[sfx]!));
    }
  }

  void setEnabled(bool v) => _enabled = v;

  Future<void> play(SFX sfx) async {
    if (!_enabled) return;
    try {
      await _players[sfx]?.seek(Duration.zero);
      await _players[sfx]?.resume();
    } catch (_) {}
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}
