import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:kurdle_app/services/settings_service.dart';

enum SFX {
  tilePickup,
  tilePlace,
  tileReturn,
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
  Future<void>? _initFuture;
  bool get enabled => _enabled;

  // Her ses için ayrı player — aynı anda birden fazla çalabilir
  final _players = <SFX, AudioPlayer>{};

  static const _files = {
    SFX.tilePickup: 'sounds/tile_pickup.wav',
    SFX.tilePlace: 'sounds/tile_place.wav',
    SFX.tileReturn: 'sounds/tile_return.wav',
    SFX.wordValid: 'sounds/word_valid.wav',
    SFX.wordInvalid: 'sounds/word_invalid.wav',
    SFX.aiTurn: 'sounds/ai_turn.wav',
    SFX.scoreUp: 'sounds/score_up.wav',
    SFX.win: 'sounds/win.wav',
    SFX.lose: 'sounds/lose.wav',
    SFX.passTurn: 'sounds/pass_turn.wav',
    SFX.tileExchange: 'sounds/tile_exchange.wav',
  };

  Future<void> init() async {
    if (_initFuture != null) return _initFuture!;
    _initFuture = _init();
    return _initFuture!;
  }

  Future<void> _init() async {
    try {
      final settings = await SettingsService().load();
      _enabled = settings.soundEnabled;
    } catch (e) {
      debugPrint('SoundService settings load failed: $e');
    }

    for (final sfx in SFX.values) {
      final player = AudioPlayer();
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setVolume(1.0);
      await player.setSource(AssetSource(_files[sfx]!));
      _players[sfx] = player;
    }
  }

  void setEnabled(bool v) => _enabled = v;

  Future<void> play(SFX sfx) async {
    if (!_enabled) return;
    try {
      if (_players[sfx] == null) {
        await init();
      }
      final player = _players[sfx];
      if (player == null) return;
      await player.stop();
      await player.setSource(AssetSource(_files[sfx]!));
      await player.resume();
    } catch (e) {
      debugPrint('SoundService play failed for $sfx: $e');
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
    _initFuture = null;
  }
}
