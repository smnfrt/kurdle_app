import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/board_layout_service.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/tile_bag_service.dart';

class MultiplayerRoom {
  final String roomCode;
  final String hostUid;
  final String hostName;
  final String? guestUid;
  final String? guestName;
  final String status; // waiting | active | finished
  final String currentTurnUid;
  final int hostScore;
  final int guestScore;
  final List<String> hostRack;
  final List<String> guestRack;
  final List<String> bagLetters;
  final List<Map<String, dynamic>> boardState;
  final String? winner; // host | guest | draw
  final int passCount;
  final String? inviteeUid;
  final int hostStealsLeft;
  final int guestStealsLeft;
  final int? lastMoveScore;
  final String? lastMoveBy; // 'host' | 'guest'
  final List<Map<String, dynamic>> lastMoveWords;
  final List<String> lastMoveCells;

  const MultiplayerRoom({
    required this.roomCode,
    required this.hostUid,
    required this.hostName,
    this.guestUid,
    this.guestName,
    required this.status,
    required this.currentTurnUid,
    this.hostScore = 0,
    this.guestScore = 0,
    this.hostRack = const [],
    this.guestRack = const [],
    this.bagLetters = const [],
    this.boardState = const [],
    this.winner,
    this.passCount = 0,
    this.inviteeUid,
    this.hostStealsLeft = 2,
    this.guestStealsLeft = 2,
    this.lastMoveScore,
    this.lastMoveBy,
    this.lastMoveWords = const [],
    this.lastMoveCells = const [],
  });

  factory MultiplayerRoom.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MultiplayerRoom(
      roomCode: doc.id,
      hostUid: d['hostUid'] ?? '',
      hostName: d['hostName'] ?? 'Oyuncu',
      guestUid: d['guestUid'],
      guestName: d['guestName'],
      status: d['status'] ?? 'waiting',
      currentTurnUid: d['currentTurnUid'] ?? '',
      hostScore: d['hostScore'] ?? 0,
      guestScore: d['guestScore'] ?? 0,
      hostRack: List<String>.from(d['hostRack'] ?? []),
      guestRack: List<String>.from(d['guestRack'] ?? []),
      bagLetters: List<String>.from(d['bagLetters'] ?? []),
      boardState: List<Map<String, dynamic>>.from(d['boardState'] ?? []),
      winner: d['winner'],
      passCount: d['passCount'] ?? 0,
      inviteeUid: d['inviteeUid'],
      hostStealsLeft: d['hostStealsLeft'] ?? 2,
      guestStealsLeft: d['guestStealsLeft'] ?? 2,
      lastMoveScore: d['lastMoveScore'] as int?,
      lastMoveBy: d['lastMoveBy'] as String?,
      lastMoveWords: List<Map<String, dynamic>>.from(d['lastMoveWords'] ?? []),
      lastMoveCells: List<String>.from(d['lastMoveCells'] ?? []),
    );
  }

  WordBoard toWordBoard() {
    var board = BoardLayoutService.createClassicLayout();
    for (final cell in boardState) {
      board = board.placeLetter(
        cell['r'] as int,
        cell['c'] as int,
        cell['l'] as String,
      );
    }
    return board;
  }

  static List<GameTile> toRack(List<String> letters) {
    return letters
        .asMap()
        .entries
        .map((e) => GameTile(id: 'rack_${e.key}_${e.value}', letter: e.value))
        .toList();
  }
}

class MultiplayerService {
  MultiplayerService._();
  static final MultiplayerService instance = MultiplayerService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference get _rooms => _db.collection('rooms');

  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _generateCode() {
    final rng = Random();
    return String.fromCharCodes(
      List.generate(6, (_) => _chars.codeUnitAt(rng.nextInt(_chars.length))),
    );
  }

  Future<String> createRoom(String uid, String displayName) async {
    final config = LanguageConfig.current;
    final bag = TileBagService(config.tileBag);
    final hostRack = bag.drawMany(7).map((t) => t.letter).toList();
    final guestRack = bag.drawMany(7).map((t) => t.letter).toList();
    final bagLetters = <String>[];
    while (bag.remaining > 0) {
      final t = bag.drawOne();
      if (t != null) bagLetters.add(t.letter);
    }

    String code = _generateCode();
    for (var i = 0; i < 5; i++) {
      final snap = await _rooms.doc(code).get();
      if (!snap.exists) break;
      code = _generateCode();
    }

    await _rooms.doc(code).set({
      'hostUid': uid,
      'hostName': displayName,
      'guestUid': null,
      'guestName': null,
      'status': 'waiting',
      'currentTurnUid': uid,
      'hostScore': 0,
      'guestScore': 0,
      'hostRack': hostRack,
      'guestRack': guestRack,
      'bagLetters': bagLetters,
      'boardState': [],
      'winner': null,
      'passCount': 0,
      'hostStealsLeft': 2,
      'guestStealsLeft': 2,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMoveAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  Future<String?> joinRoom(
      String rawCode, String uid, String displayName) async {
    final code = rawCode.toUpperCase().trim();
    try {
      await _db.runTransaction((tx) async {
        final ref = _rooms.doc(code);
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('Oda bulunamadı');
        final d = snap.data() as Map<String, dynamic>;
        final status = d['status'] as String? ?? '';
        if (!status.startsWith('waiting'))
          throw Exception('Oda dolu veya oyun bitti');
        if (d['hostUid'] == uid) throw Exception('Kendi odana katılamazsın');
        tx.update(ref, {
          'guestUid': uid,
          'guestName': displayName,
          'status': 'active',
        });
      });
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Mevcut rastgele bekleme odasına katıl, yoksa yeni oluştur.
  Future<String> findOrCreateRandomRoom(String uid, String displayName) async {
    final snap = await _rooms
        .where('status', isEqualTo: 'waiting_random')
        .limit(10)
        .get();

    for (final doc in snap.docs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['hostUid'] == uid) continue;
      final err = await joinRoom(doc.id, uid, displayName);
      if (err == null) return doc.id;
    }

    return _createRandomRoom(uid, displayName);
  }

  Future<String> _createRandomRoom(String uid, String displayName) async {
    final config = LanguageConfig.current;
    final bag = TileBagService(config.tileBag);
    final hostRack = bag.drawMany(7).map((t) => t.letter).toList();
    final guestRack = bag.drawMany(7).map((t) => t.letter).toList();
    final bagLetters = <String>[];
    while (bag.remaining > 0) {
      final t = bag.drawOne();
      if (t != null) bagLetters.add(t.letter);
    }

    String code = _generateCode();
    for (var i = 0; i < 5; i++) {
      final s = await _rooms.doc(code).get();
      if (!s.exists) break;
      code = _generateCode();
    }

    await _rooms.doc(code).set({
      'hostUid': uid,
      'hostName': displayName,
      'guestUid': null,
      'guestName': null,
      'status': 'waiting_random',
      'currentTurnUid': uid,
      'hostScore': 0,
      'guestScore': 0,
      'hostRack': hostRack,
      'guestRack': guestRack,
      'bagLetters': bagLetters,
      'boardState': [],
      'winner': null,
      'passCount': 0,
      'hostStealsLeft': 2,
      'guestStealsLeft': 2,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMoveAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  /// Rastgele arama iptal edildiğinde odayı sil.
  Future<void> cancelRandomSearch(String roomCode) async {
    try {
      final snap = await _rooms.doc(roomCode).get();
      if (!snap.exists) return;
      final d = snap.data() as Map<String, dynamic>;
      if ((d['status'] as String? ?? '').startsWith('waiting')) {
        await _rooms.doc(roomCode).delete();
      }
    } catch (_) {}
  }

  /// Kullanıcı adıyla davet odası oluştur.
  Future<String> createInviteRoom(
      String uid, String displayName, String inviteeUid) async {
    final config = LanguageConfig.current;
    final bag = TileBagService(config.tileBag);
    final hostRack = bag.drawMany(7).map((t) => t.letter).toList();
    final guestRack = bag.drawMany(7).map((t) => t.letter).toList();
    final bagLetters = <String>[];
    while (bag.remaining > 0) {
      final t = bag.drawOne();
      if (t != null) bagLetters.add(t.letter);
    }

    String code = _generateCode();
    for (var i = 0; i < 5; i++) {
      final s = await _rooms.doc(code).get();
      if (!s.exists) break;
      code = _generateCode();
    }

    await _rooms.doc(code).set({
      'hostUid': uid,
      'hostName': displayName,
      'guestUid': null,
      'guestName': null,
      'status': 'waiting_invite',
      'inviteeUid': inviteeUid,
      'currentTurnUid': uid,
      'hostScore': 0,
      'guestScore': 0,
      'hostRack': hostRack,
      'guestRack': guestRack,
      'bagLetters': bagLetters,
      'boardState': [],
      'winner': null,
      'passCount': 0,
      'hostStealsLeft': 2,
      'guestStealsLeft': 2,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMoveAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  /// Benim için bekleyen davetleri gerçek zamanlı izler.
  Stream<List<MultiplayerRoom>> inviteStream(String myUid) {
    return _rooms.where('inviteeUid', isEqualTo: myUid).snapshots().map(
        (snap) => snap.docs
            .map((d) => MultiplayerRoom.fromDoc(d))
            .where((r) => r.status == 'waiting_invite')
            .toList());
  }

  /// Daveti reddet (odayı sil).
  Future<void> declineInvite(String roomCode) async {
    try {
      await _rooms.doc(roomCode).delete();
    } catch (_) {}
  }

  /// Kullanıcının aktif çok oyunculu oyunlarını gerçek zamanlı izler.
  Stream<List<MultiplayerRoom>> myActiveRoomsStream(String uid) {
    final ctrl = StreamController<List<MultiplayerRoom>>();
    List<MultiplayerRoom> asHost = [];
    List<MultiplayerRoom> asGuest = [];

    void emit() {
      if (!ctrl.isClosed) ctrl.add([...asHost, ...asGuest]);
    }

    final subHost = _rooms
        .where('hostUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      asHost = snap.docs.map((d) => MultiplayerRoom.fromDoc(d)).toList();
      emit();
    });

    final subGuest = _rooms
        .where('guestUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen((snap) {
      asGuest = snap.docs.map((d) => MultiplayerRoom.fromDoc(d)).toList();
      emit();
    });

    ctrl.onCancel = () {
      subHost.cancel();
      subGuest.cancel();
    };

    return ctrl.stream;
  }

  Stream<MultiplayerRoom?> roomStream(String roomCode) {
    return _rooms.doc(roomCode).snapshots().map((snap) {
      if (!snap.exists) return null;
      return MultiplayerRoom.fromDoc(snap);
    });
  }

  Future<void> submitMove({
    required String roomCode,
    required bool isHost,
    required int myScore,
    required List<String> myNewRack,
    required List<String> newBagLetters,
    required List<Map<String, dynamic>> newBoardState,
    required String nextTurnUid,
    required bool isGameOver,
    required String? winner,
    int? myNewStealsLeft,
    int? moveScore,
    List<Map<String, dynamic>> lastMoveWords = const [],
    List<String> lastMoveCells = const [],
  }) async {
    final update = <String, dynamic>{
      'boardState': newBoardState,
      'bagLetters': newBagLetters,
      'currentTurnUid': nextTurnUid,
      'passCount': 0,
      'lastMoveAt': FieldValue.serverTimestamp(),
      'lastMoveScore': moveScore,
      'lastMoveBy': isHost ? 'host' : 'guest',
      'lastMoveWords': lastMoveWords,
      'lastMoveCells': lastMoveCells,
    };
    if (isHost) {
      update['hostScore'] = myScore;
      update['hostRack'] = myNewRack;
      if (myNewStealsLeft != null) update['hostStealsLeft'] = myNewStealsLeft;
    } else {
      update['guestScore'] = myScore;
      update['guestRack'] = myNewRack;
      if (myNewStealsLeft != null) update['guestStealsLeft'] = myNewStealsLeft;
    }
    if (isGameOver) {
      update['status'] = 'finished';
      update['winner'] = winner;
    }
    await _rooms.doc(roomCode).update(update);
  }

  Future<void> passTurn({
    required String roomCode,
    required String nextTurnUid,
    required int currentPassCount,
    required int hostScore,
    required int guestScore,
  }) async {
    final newCount = currentPassCount + 1;
    final update = <String, dynamic>{
      'currentTurnUid': nextTurnUid,
      'passCount': newCount,
      'lastMoveAt': FieldValue.serverTimestamp(),
      'lastMoveWords': [],
      'lastMoveCells': [],
    };
    if (newCount >= 4) {
      update['status'] = 'finished';
      update['winner'] = hostScore > guestScore
          ? 'host'
          : guestScore > hostScore
              ? 'guest'
              : 'draw';
    }
    await _rooms.doc(roomCode).update(update);
  }

  Future<void> leaveRoom(String roomCode, String uid) async {
    try {
      final snap = await _rooms.doc(roomCode).get();
      if (!snap.exists) return;
      final d = snap.data() as Map<String, dynamic>;
      if (d['status'] == 'finished') return;
      final isHost = d['hostUid'] == uid;
      await _rooms.doc(roomCode).update({
        'status': 'finished',
        'winner': isHost ? 'guest' : 'host',
      });
    } catch (_) {}
  }

  static List<Map<String, dynamic>> serializeBoard(WordBoard board) {
    return board.cells
        .where((c) => c.isLocked)
        .map((c) => {'r': c.row, 'c': c.column, 'l': c.letter})
        .toList();
  }
}
