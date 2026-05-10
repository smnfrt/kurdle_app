import 'package:kurdle_app/controllers/scrabble_game_controller.dart';

class GameRecord {
  final String id;
  final DateTime startedAt;
  int playerScore;
  int aiScore;
  bool isFinished;
  DateTime? lastMoveAt;

  GameRecord({
    required this.id,
    required this.startedAt,
    this.playerScore = 0,
    this.aiScore = 0,
    this.isFinished = false,
    this.lastMoveAt,
  });
}

class GameStore {
  static final GameStore instance = GameStore._();
  GameStore._();

  final List<GameRecord> records = [];
  ScrabbleGameController? activeController;
  String? activeRecordId;

  int dailyBonusPoints = 0;

  static const int _maxRecords = 20;

  GameRecord createRecord() {
    final record = GameRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startedAt: DateTime.now(),
    );
    records.insert(0, record);
    activeRecordId = record.id;
    if (records.length > _maxRecords) {
      records.removeRange(_maxRecords, records.length);
    }
    return record;
  }

  void sync(ScrabbleGameController ctrl, {bool moveMade = false}) {
    final idx = records.indexWhere((r) => r.id == activeRecordId);
    if (idx < 0) return;
    records[idx].playerScore = ctrl.playerScore;
    records[idx].aiScore    = ctrl.aiScore;
    records[idx].isFinished = ctrl.phase == GamePhase.gameOver;
    if (moveMade) records[idx].lastMoveAt = DateTime.now();
  }

  GameRecord? get activeRecord {
    if (activeRecordId == null) return null;
    try {
      return records.firstWhere((r) => r.id == activeRecordId);
    } catch (_) {
      return null;
    }
  }
}
