import 'package:flutter_test/flutter_test.dart';
import 'package:kurdle_app/controllers/scrabble_game_controller.dart'
    show GamePhase, ScrabbleGameController;
import 'package:kurdle_app/domain.dart' show AiDifficulty;
import 'package:shared_preferences/shared_preferences.dart';

const _kSampleWordlist = ['AV', 'HESP', 'JIN', 'MAL', 'XER', 'ZÊR'];

ScrabbleGameController _newController() {
  return ScrabbleGameController(
    _kSampleWordlist,
    turnTimeLimitSeconds: null,
    aiDifficulty: AiDifficulty.easy,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('initial state', () {
    test('player rack filled to rackSize, AI rack too', () {
      final ctrl = _newController();
      expect(ctrl.playerRack.length, ScrabbleGameController.rackSize);
      expect(ctrl.aiRack.length, ScrabbleGameController.rackSize);
    });

    test('scores start at zero', () {
      final ctrl = _newController();
      expect(ctrl.playerScore, 0);
      expect(ctrl.aiScore, 0);
    });

    test('phase starts as playerTurn', () {
      final ctrl = _newController();
      expect(ctrl.phase, GamePhase.playerTurn);
    });

    test('no last move on fresh game', () {
      final ctrl = _newController();
      expect(ctrl.lastMoveWords, isEmpty);
      expect(ctrl.lastPlayerMoveWords, isEmpty);
      expect(ctrl.lastMoveCells, isEmpty);
    });

    test('pass count starts at zero, full quota available', () {
      final ctrl = _newController();
      expect(ctrl.playerPassCount, 0);
      expect(ctrl.passesLeft, ScrabbleGameController.maxPlayerPasses);
    });

    test('all steals available', () {
      final ctrl = _newController();
      expect(ctrl.playerStealsLeft, ScrabbleGameController.maxStealsPerGame);
      expect(ctrl.isInStealMode, false);
    });

    test('full enhance budget available', () {
      final ctrl = _newController();
      expect(ctrl.playerEnhancesLeft,
          ScrabbleGameController.maxEnhancesPerGame);
    });
  });

  group('placeTile / recallTile / recallAll', () {
    test('placeTile moves tile from rack to board pending', () {
      final ctrl = _newController();
      final tile = ctrl.playerRack.first;
      final rackSizeBefore = ctrl.playerRack.length;
      ctrl.placeTile(7, 7, tile);
      expect(ctrl.playerRack.length, rackSizeBefore - 1);
      expect(ctrl.board.pendingCells.length, 1);
      expect(ctrl.board.cellAt(7, 7).letter, tile.letter);
    });

    test('recallTile returns tile to rack', () {
      final ctrl = _newController();
      final tile = ctrl.playerRack.first;
      ctrl.placeTile(7, 7, tile);
      ctrl.recallTile(7, 7);
      expect(ctrl.playerRack.length, ScrabbleGameController.rackSize);
      expect(ctrl.board.pendingCells, isEmpty);
    });

    test('recallAll clears all pending tiles', () {
      final ctrl = _newController();
      final t1 = ctrl.playerRack[0];
      final t2 = ctrl.playerRack[1];
      ctrl.placeTile(7, 7, t1);
      ctrl.placeTile(7, 8, t2);
      expect(ctrl.board.pendingCells.length, 2);
      ctrl.recallAll();
      expect(ctrl.playerRack.length, ScrabbleGameController.rackSize);
      expect(ctrl.board.pendingCells, isEmpty);
    });
  });

  group('shuffleRack', () {
    test('preserves tile set', () {
      final ctrl = _newController();
      final before = ctrl.playerRack.map((t) => t.id).toSet();
      ctrl.shuffleRack();
      final after = ctrl.playerRack.map((t) => t.id).toSet();
      expect(after, before);
    });
  });

  group('setMeaningPopupOpen', () {
    test('flag toggles cleanly', () {
      final ctrl = _newController();
      ctrl.setMeaningPopupOpen(true);
      ctrl.setMeaningPopupOpen(false);
      // No state to observe directly other than not crashing — internal flag
      // is private; integration with _scheduleAiMove tested via game flow.
      expect(ctrl.phase, GamePhase.playerTurn);
    });
  });

  group('toggleStealMode', () {
    test('activates when steals available', () {
      final ctrl = _newController();
      ctrl.toggleStealMode();
      expect(ctrl.isInStealMode, true);
    });

    test('deactivates when toggled again', () {
      final ctrl = _newController();
      ctrl.toggleStealMode();
      ctrl.toggleStealMode();
      expect(ctrl.isInStealMode, false);
    });

    test('refuses when no steals left', () {
      final ctrl = _newController();
      // Force steals to zero
      ctrl.playerStealsLeft = 0;
      ctrl.toggleStealMode();
      expect(ctrl.isInStealMode, false);
      expect(ctrl.message, isNotEmpty);
    });
  });

  group('resign', () {
    test('sets gameOver phase', () {
      final ctrl = _newController();
      ctrl.resign();
      expect(ctrl.phase, GamePhase.gameOver);
    });
  });
}
