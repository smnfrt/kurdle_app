import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:kurdle_app/models/game_tile.dart';
import 'package:kurdle_app/models/word_board.dart';
import 'package:kurdle_app/services/board_layout_service.dart';
import 'package:kurdle_app/services/language_config.dart';
import 'package:kurdle_app/services/logging_service.dart';
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
  final String gameType;
  final int hostStealsLeft;
  final int guestStealsLeft;
  final int? lastMoveScore;
  final String? lastMoveBy; // 'host' | 'guest'
  final List<Map<String, dynamic>> lastMoveWords;
  final List<String> lastMoveCells;
  final DateTime? lastMoveAt;
  final int? turnTimeLimitSeconds;
  final DateTime? turnStartedAt;
  final DateTime? turnDeadlineAt;
  // Game over metadata (status=finished olduğunda doluyor)
  final String? finishReason; // natural_end | pass_limit | forfeit | timeout
  final String? finishedBy; // forfeit yapan veya süresi dolan uid (varsa)
  final DateTime? finishedAt;

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
    this.gameType = 'scrabble',
    this.hostStealsLeft = 2,
    this.guestStealsLeft = 2,
    this.lastMoveScore,
    this.lastMoveBy,
    this.lastMoveWords = const [],
    this.lastMoveCells = const [],
    this.lastMoveAt,
    this.turnTimeLimitSeconds,
    this.turnStartedAt,
    this.turnDeadlineAt,
    this.finishReason,
    this.finishedBy,
    this.finishedAt,
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
      gameType: d['gameType'] as String? ?? 'scrabble',
      hostStealsLeft: d['hostStealsLeft'] ?? 2,
      guestStealsLeft: d['guestStealsLeft'] ?? 2,
      lastMoveScore: d['lastMoveScore'] as int?,
      lastMoveBy: d['lastMoveBy'] as String?,
      lastMoveWords: List<Map<String, dynamic>>.from(d['lastMoveWords'] ?? []),
      lastMoveCells: List<String>.from(d['lastMoveCells'] ?? []),
      lastMoveAt: (d['lastMoveAt'] as Timestamp?)?.toDate(),
      turnTimeLimitSeconds: (d['turnTimeLimitSeconds'] as num?)?.toInt(),
      turnStartedAt: (d['turnStartedAt'] as Timestamp?)?.toDate(),
      turnDeadlineAt: (d['turnDeadlineAt'] as Timestamp?)?.toDate(),
      finishReason: d['finishReason'] as String?,
      finishedBy: d['finishedBy'] as String?,
      finishedAt: (d['finishedAt'] as Timestamp?)?.toDate(),
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

class PendingInviteException implements Exception {
  final String roomCode;

  const PendingInviteException(this.roomCode);

  String get inviteId => roomCode;

  @override
  String toString() => 'pending_invite_exists:$roomCode';
}

class GameInvite {
  final String inviteId;
  final String fromUserId;
  final String fromDisplayName;
  final String toUserId;
  final String toDisplayName;
  final String status;
  final String? roomCode;
  final DateTime? createdAt;
  final DateTime expiresAt;
  final DateTime? acceptedAt;
  final DateTime? cancelledAt;
  final String? gameId;
  final String gameType;
  final int? turnTimeLimitSeconds;

  const GameInvite({
    required this.inviteId,
    required this.fromUserId,
    required this.fromDisplayName,
    required this.toUserId,
    required this.toDisplayName,
    required this.status,
    this.roomCode,
    this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
    this.cancelledAt,
    this.gameId,
    this.gameType = 'scrabble',
    this.turnTimeLimitSeconds,
  });

  bool get isPending => status == 'pending';
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  factory GameInvite.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final expiresAt =
        (d['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    return GameInvite(
      inviteId: d['inviteId'] as String? ?? doc.id,
      fromUserId: d['fromUserId'] as String? ?? '',
      fromDisplayName: d['fromDisplayName'] as String? ?? 'Oyuncu',
      toUserId: d['toUserId'] as String? ?? '',
      toDisplayName: d['toDisplayName'] as String? ?? 'Oyuncu',
      status: d['status'] as String? ?? 'pending',
      roomCode: d['roomCode'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: expiresAt,
      acceptedAt: (d['acceptedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (d['cancelledAt'] as Timestamp?)?.toDate(),
      gameId: d['gameId'] as String?,
      gameType: d['gameType'] as String? ?? 'scrabble',
      turnTimeLimitSeconds: (d['turnTimeLimitSeconds'] as num?)?.toInt(),
    );
  }
}

class MultiplayerService {
  MultiplayerService._();
  static final MultiplayerService instance = MultiplayerService._();

  final _db = FirebaseFirestore.instance;
  CollectionReference get _rooms => _db.collection('rooms');
  CollectionReference get _gameInvites => _db.collection('gameInvites');

  static const _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const inviteValidity = Duration(hours: 48);
  static const defaultTurnTimeLimitSeconds = 24 * 60 * 60;

  void _debugLog(String message) {
    if (kDebugMode) debugPrint('[MultiplayerService] $message');
  }

  String _generateCode() {
    final rng = Random();
    return String.fromCharCodes(
      List.generate(6, (_) => _chars.codeUnitAt(rng.nextInt(_chars.length))),
    );
  }

  Future<String> _newRoomCode() async {
    String code = _generateCode();
    for (var i = 0; i < 8; i++) {
      final snap = await _rooms.doc(code).get();
      if (!snap.exists) return code;
      code = _generateCode();
    }
    return code;
  }

  Map<String, dynamic> _initialRoomData({
    required String hostUid,
    required String hostName,
    required String? guestUid,
    required String? guestName,
    required String status,
    String? inviteeUid,
    String gameType = 'scrabble',
    String? inviteId,
    int? turnTimeLimitSeconds,
  }) {
    final config = LanguageConfig.current;
    final bag = TileBagService(config.tileBag);
    final hostRack = bag.drawMany(7).map((t) => t.letter).toList();
    final guestRack = bag.drawMany(7).map((t) => t.letter).toList();
    final bagLetters = <String>[];
    while (bag.remaining > 0) {
      final t = bag.drawOne();
      if (t != null) bagLetters.add(t.letter);
    }

    final limit = turnTimeLimitSeconds ?? defaultTurnTimeLimitSeconds;

    return {
      'hostUid': hostUid,
      'hostName': hostName,
      'guestUid': guestUid,
      'guestName': guestName,
      'status': status,
      if (inviteeUid != null) 'inviteeUid': inviteeUid,
      if (inviteId != null) 'inviteId': inviteId,
      'gameType': gameType,
      'turnTimeLimitSeconds': limit,
      'currentTurnUid': hostUid,
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
      if (status == 'active') ...{
        'turnStartedAt': FieldValue.serverTimestamp(),
        'turnDeadlineAt': Timestamp.fromDate(
          DateTime.now().add(Duration(seconds: limit)),
        ),
      },
    };
  }

  Future<String> createRoom(
    String uid,
    String displayName, {
    int? turnTimeLimitSeconds,
  }) async {
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

    final limit = turnTimeLimitSeconds ?? defaultTurnTimeLimitSeconds;

    await _rooms.doc(code).set({
      'hostUid': uid,
      'hostName': displayName,
      'guestUid': null,
      'guestName': null,
      'status': 'waiting',
      'turnTimeLimitSeconds': limit,
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
      'turnStartedAt': null,
      'turnDeadlineAt': null,
    });

    _debugLog('createRoom code=$code host=$uid status=waiting');
    return code;
  }

  Future<String?> joinRoom(
      String rawCode, String uid, String displayName) async {
    final code = rawCode.toUpperCase().trim();
    try {
      await _db.runTransaction((tx) async {
        final ref = _rooms.doc(code);
        final snap = await tx.get(ref);
        if (!snap.exists) throw Exception('room_not_found');
        final d = snap.data() as Map<String, dynamic>;
        final status = d['status'] as String? ?? '';
        if (!status.startsWith('waiting')) throw Exception('room_unavailable');
        if (d['hostUid'] == uid) throw Exception('cannot_join_own_room');
        final limit = (d['turnTimeLimitSeconds'] as num?)?.toInt();
        tx.update(ref, {
          'guestUid': uid,
          'guestName': displayName,
          'status': 'active',
          if (limit != null) ...{
            'turnStartedAt': FieldValue.serverTimestamp(),
            'turnDeadlineAt': Timestamp.fromDate(
                DateTime.now().add(Duration(seconds: limit))),
          },
        });
      });
      _debugLog('joinRoom code=$code guest=$uid status=active');
      return null;
    } catch (e) {
      _debugLog('joinRoom failed code=$code guest=$uid error=$e');
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
      'turnTimeLimitSeconds': defaultTurnTimeLimitSeconds,
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

    _debugLog('createRandomRoom code=$code host=$uid status=waiting_random');
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
    } catch (e) {
      Log.warn('MultiplayerService', 'cancelRandomSearch failed', e);
    }
  }

  /// Kullanıcı adıyla davet odası oluştur.
  Future<String> createInviteRoom(
    String uid,
    String displayName,
    String inviteeUid, {
    String gameType = 'scrabble',
    int? turnTimeLimitSeconds,
  }) async {
    final existing = await _existingInviteRoom(
      hostUid: uid,
      inviteeUid: inviteeUid,
      gameType: gameType,
    );
    if (existing != null) {
      _debugLog(
          'createInviteRoom blocked duplicate code=$existing host=$uid invitee=$inviteeUid gameType=$gameType');
      throw PendingInviteException(existing);
    }

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

    final limit = turnTimeLimitSeconds ?? defaultTurnTimeLimitSeconds;

    await _rooms.doc(code).set({
      'hostUid': uid,
      'hostName': displayName,
      'guestUid': null,
      'guestName': null,
      'status': 'waiting_invite',
      'inviteeUid': inviteeUid,
      'gameType': gameType,
      'turnTimeLimitSeconds': limit,
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
      'turnStartedAt': null,
      'turnDeadlineAt': null,
    });

    _debugLog(
        'createInviteRoom code=$code host=$uid invitee=$inviteeUid gameType=$gameType status=waiting_invite');
    return code;
  }

  Future<String?> _existingInviteRoom({
    required String hostUid,
    required String inviteeUid,
    required String gameType,
  }) async {
    final hostSnaps = await Future.wait([
      _rooms.where('hostUid', isEqualTo: hostUid).limit(50).get(),
      _rooms.where('hostUid', isEqualTo: inviteeUid).limit(50).get(),
    ]);
    for (final snap in hostSnaps) {
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final existingGameType = data['gameType'] as String? ?? 'scrabble';
        final isSameDirection =
            data['hostUid'] == hostUid && data['inviteeUid'] == inviteeUid;
        final isOppositeDirection =
            data['hostUid'] == inviteeUid && data['inviteeUid'] == hostUid;
        if (data['status'] == 'waiting_invite' &&
            (isSameDirection || isOppositeDirection) &&
            existingGameType == gameType) {
          return doc.id;
        }
      }
    }
    return null;
  }

  Future<GameInvite?> _existingPendingInvite({
    required String fromUserId,
    required String toUserId,
    required String gameType,
  }) async {
    final snaps = await Future.wait([
      _gameInvites
          .where('fromUserId', isEqualTo: fromUserId)
          .where('toUserId', isEqualTo: toUserId)
          .limit(20)
          .get(),
      _gameInvites
          .where('fromUserId', isEqualTo: toUserId)
          .where('toUserId', isEqualTo: fromUserId)
          .limit(20)
          .get(),
    ]);
    for (final snap in snaps) {
      for (final doc in snap.docs) {
        final invite = GameInvite.fromDoc(doc);
        final sameDirection =
            invite.fromUserId == fromUserId && invite.toUserId == toUserId;
        final oppositeDirection =
            invite.fromUserId == toUserId && invite.toUserId == fromUserId;
        if (!invite.isPending ||
            invite.gameType != gameType ||
            (!sameDirection && !oppositeDirection)) {
          continue;
        }
        if (invite.isExpired) {
          await _markInviteExpired(invite.inviteId);
          continue;
        }
        return invite;
      }
    }
    return null;
  }

  /// Arkadaşa kalıcı davet oluşturur. Oyun odası kabul anında açılır.
  Future<GameInvite> createPersistentInvite(
    String fromUserId,
    String fromDisplayName,
    String toUserId,
    String toDisplayName, {
    String gameType = 'scrabble',
    int? turnTimeLimitSeconds,
  }) async {
    final existing = await _existingPendingInvite(
      fromUserId: fromUserId,
      toUserId: toUserId,
      gameType: gameType,
    );
    if (existing != null) {
      _debugLog(
          'createPersistentInvite blocked duplicate invite=${existing.inviteId} from=$fromUserId to=$toUserId gameType=$gameType');
      throw PendingInviteException(existing.inviteId);
    }

    final ref = _gameInvites.doc();
    final expiresAt = DateTime.now().add(inviteValidity);
    final limit = turnTimeLimitSeconds ?? defaultTurnTimeLimitSeconds;
    final data = {
      'inviteId': ref.id,
      'fromUserId': fromUserId,
      'fromDisplayName': fromDisplayName,
      'toUserId': toUserId,
      'toDisplayName': toDisplayName,
      'status': 'pending',
      'roomCode': null,
      'gameType': gameType,
      'turnTimeLimitSeconds': limit,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'acceptedAt': null,
      'cancelledAt': null,
      'gameId': null,
    };
    await ref.set(data);
    _debugLog(
        'createPersistentInvite invite=${ref.id} from=$fromUserId to=$toUserId expires=$expiresAt');
    return GameInvite.fromDoc(await ref.get());
  }

  /// Benim için bekleyen kalıcı davetleri gerçek zamanlı izler.
  Stream<List<GameInvite>> inviteStream(String myUid) {
    return _gameInvites
        .where('toUserId', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final invites = <GameInvite>[];
      for (final doc in snap.docs) {
        final invite = GameInvite.fromDoc(doc);
        if (invite.expiresAt.isAfter(now)) {
          invites.add(invite);
        } else {
          _markInviteExpired(invite.inviteId);
        }
      }
      invites.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return invites;
    });
  }

  Stream<GameInvite?> inviteDocStream(String inviteId) {
    return _gameInvites.doc(inviteId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return GameInvite.fromDoc(snap);
    });
  }

  Future<GameInvite?> getInvite(String inviteId) async {
    final snap = await _gameInvites.doc(inviteId).get();
    if (!snap.exists) return null;
    final invite = GameInvite.fromDoc(snap);
    if (invite.isPending && invite.isExpired) {
      await _markInviteExpired(invite.inviteId);
      return null;
    }
    return invite;
  }

  Future<String> acceptInvite(
    GameInvite invite,
    String uid,
    String displayName,
  ) async {
    final code = await _newRoomCode();
    final roomData = _initialRoomData(
      hostUid: invite.fromUserId,
      hostName: invite.fromDisplayName,
      guestUid: uid,
      guestName: displayName,
      status: 'active',
      inviteId: invite.inviteId,
      gameType: invite.gameType,
      turnTimeLimitSeconds: invite.turnTimeLimitSeconds,
    );

    return _db.runTransaction<String>((tx) async {
      final inviteRef = _gameInvites.doc(invite.inviteId);
      final roomRef = _rooms.doc(code);
      final inviteSnap = await tx.get(inviteRef);
      final roomSnap = await tx.get(roomRef);
      if (!inviteSnap.exists) throw Exception('invite_not_found');
      if (roomSnap.exists) throw Exception('room_code_collision');
      final current = GameInvite.fromDoc(inviteSnap);
      if (current.toUserId != uid) throw Exception('invite_for_another_user');
      if (current.status != 'pending') throw Exception('invite_unavailable');
      if (current.isExpired) {
        tx.update(inviteRef, {'status': 'expired'});
        throw Exception('invite_expired');
      }
      tx.set(roomRef, roomData);
      tx.update(inviteRef, {
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'roomCode': code,
        'gameId': code,
      });
      return code;
    });
  }

  /// Daveti reddet.
  Future<void> declineInvite(String inviteId) async {
    try {
      await _gameInvites.doc(inviteId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      Log.warn('MultiplayerService', 'declineInvite failed', e);
    }
  }

  Future<void> cancelInvite(String inviteId, String uid) async {
    try {
      await _db.runTransaction((tx) async {
        final ref = _gameInvites.doc(inviteId);
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final invite = GameInvite.fromDoc(snap);
        if (invite.fromUserId != uid || invite.status != 'pending') return;
        tx.update(ref, {
          'status': 'cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      Log.warn('MultiplayerService', 'cancelInvite failed', e);
    }
  }

  Future<void> _markInviteExpired(String inviteId) async {
    try {
      await _gameInvites.doc(inviteId).update({'status': 'expired'});
    } catch (_) {
      // Best effort: client UI already hides expired invites.
    }
  }

  /// Kullanıcının aktif çok oyunculu oyunlarını gerçek zamanlı izler.
  Stream<List<MultiplayerRoom>> myActiveRoomsStream(String uid) {
    final ctrl = StreamController<List<MultiplayerRoom>>();
    List<MultiplayerRoom> asHost = [];
    List<MultiplayerRoom> asGuest = [];

    void emit() {
      if (ctrl.isClosed) return;
      final rooms = [...asHost, ...asGuest]..sort((a, b) {
          final aTime = a.lastMoveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.lastMoveAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        });
      ctrl.add(rooms);
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

  Future<MultiplayerRoom?> getRoom(String roomCode) async {
    final snap = await _rooms.doc(roomCode).get();
    if (!snap.exists) return null;
    return MultiplayerRoom.fromDoc(snap);
  }

  bool _applyTimeoutIfNeeded(
      Map<String, dynamic> d, Map<String, dynamic> update,
      {DateTime? now}) {
    if (d['status'] != 'active') return false;
    final deadline = (d['turnDeadlineAt'] as Timestamp?)?.toDate();
    if (deadline == null) return false;
    final currentTime = now ?? DateTime.now();
    if (deadline.isAfter(currentTime)) return false;

    final timedOutUid = d['currentTurnUid'] as String? ?? '';
    final hostUid = d['hostUid'] as String? ?? '';
    final guestUid = d['guestUid'] as String? ?? '';
    update
      ..clear()
      ..addAll({
        'status': 'finished',
        'winner': timedOutUid == hostUid
            ? 'guest'
            : timedOutUid == guestUid
                ? 'host'
                : null,
        'finishReason': 'timeout',
        'finishedBy': timedOutUid,
        'finishedAt': FieldValue.serverTimestamp(),
      });
    return true;
  }

  Map<String, dynamic> _nextTurnTimerUpdate(Map<String, dynamic> d) {
    final limit = (d['turnTimeLimitSeconds'] as num?)?.toInt();
    if (limit == null) {
      return {
        'turnStartedAt': null,
        'turnDeadlineAt': null,
      };
    }
    return {
      'turnStartedAt': FieldValue.serverTimestamp(),
      'turnDeadlineAt':
          Timestamp.fromDate(DateTime.now().add(Duration(seconds: limit))),
    };
  }

  Future<bool> resolveTimedOutTurn(String roomCode) async {
    var timedOut = false;
    final ref = _rooms.doc(roomCode);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data() as Map<String, dynamic>;
      final update = <String, dynamic>{};
      timedOut = _applyTimeoutIfNeeded(d, update);
      if (timedOut) tx.update(ref, update);
    });
    return timedOut;
  }

  /// Kullanıcının bitmiş çok oyunculu oyunlarını döner (en yeni önce).
  /// İndekssiz çalışsın diye finishedAt yerine client-side sıralanır.
  Future<List<MultiplayerRoom>> myFinishedRooms(String uid,
      {int limit = 20}) async {
    try {
      final hostQuery = await _rooms
          .where('hostUid', isEqualTo: uid)
          .where('status', isEqualTo: 'finished')
          .limit(limit)
          .get();
      final guestQuery = await _rooms
          .where('guestUid', isEqualTo: uid)
          .where('status', isEqualTo: 'finished')
          .limit(limit)
          .get();
      final all = <MultiplayerRoom>[
        ...hostQuery.docs.map((d) => MultiplayerRoom.fromDoc(d)),
        ...guestQuery.docs.map((d) => MultiplayerRoom.fromDoc(d)),
      ];
      all.sort((a, b) {
        final aT = a.finishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bT = b.finishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bT.compareTo(aT);
      });
      return all.take(limit).toList();
    } catch (e) {
      Log.warn('MultiplayerService', 'myFinishedRooms failed', e);
      return [];
    }
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
    // Transaction + sıra-sahipliği doğrulaması: eşzamanlı/bayat hamlelerin
    // skoru/sırayı/kazananı bozmasını engeller (yarış koşulu koruması).
    final ref = _rooms.doc(roomCode);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data() as Map<String, dynamic>;
      if (d['status'] != 'active') {
        _debugLog(
            'submitMove REDDEDİLDİ room=$roomCode (status=${d['status']}, aktif değil)');
        return;
      }
      final timeoutUpdate = <String, dynamic>{};
      if (_applyTimeoutIfNeeded(d, timeoutUpdate)) {
        tx.update(ref, timeoutUpdate);
        _debugLog('submitMove REDDEDİLDİ room=$roomCode (süre doldu)');
        return;
      }
      // Sıra gerçekten bu oyuncuda mı? (server-otoritesi)
      final expectedTurnUid = isHost ? d['hostUid'] : d['guestUid'];
      if (d['currentTurnUid'] != expectedTurnUid) {
        _debugLog(
            'submitMove REDDEDİLDİ room=$roomCode (sıra bu oyuncuda değil)');
        return;
      }

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
        ..._nextTurnTimerUpdate(d),
      };
      if (isHost) {
        update['hostScore'] = myScore;
        update['hostRack'] = myNewRack;
        if (myNewStealsLeft != null) update['hostStealsLeft'] = myNewStealsLeft;
      } else {
        update['guestScore'] = myScore;
        update['guestRack'] = myNewRack;
        if (myNewStealsLeft != null) {
          update['guestStealsLeft'] = myNewStealsLeft;
        }
      }
      if (isGameOver) {
        update['status'] = 'finished';
        update['winner'] = winner;
        update['finishReason'] = 'natural_end';
        update['finishedAt'] = FieldValue.serverTimestamp();
        update['turnDeadlineAt'] = null;
      }
      tx.update(ref, update);
      _debugLog(
          'submitMove room=$roomCode next=$nextTurnUid gameOver=$isGameOver winner=$winner score=$moveScore');
    });
  }

  Future<void> passTurn({
    required String roomCode,
    required String nextTurnUid,
    required int currentPassCount,
    required int hostScore,
    required int guestScore,
  }) async {
    final ref = _rooms.doc(roomCode);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final d = snap.data() as Map<String, dynamic>;
      if (d['status'] != 'active') {
        _debugLog('passTurn REDDEDİLDİ room=$roomCode (status=${d['status']})');
        return;
      }
      final timeoutUpdate = <String, dynamic>{};
      if (_applyTimeoutIfNeeded(d, timeoutUpdate)) {
        tx.update(ref, timeoutUpdate);
        _debugLog('passTurn REDDEDİLDİ room=$roomCode (süre doldu)');
        return;
      }
      // Server-otoriteli sayaç + skorlar (param yerine — eşzamanlı pass yarışını önler).
      final currentCount =
          (d['passCount'] as num?)?.toInt() ?? currentPassCount;
      final newCount = currentCount + 1;
      final hScore = (d['hostScore'] as num?)?.toInt() ?? hostScore;
      final gScore = (d['guestScore'] as num?)?.toInt() ?? guestScore;
      final update = <String, dynamic>{
        'currentTurnUid': nextTurnUid,
        'passCount': newCount,
        'lastMoveAt': FieldValue.serverTimestamp(),
        'lastMoveWords': [],
        'lastMoveCells': [],
        ..._nextTurnTimerUpdate(d),
      };
      if (newCount >= 4) {
        update['status'] = 'finished';
        update['winner'] = hScore > gScore
            ? 'host'
            : gScore > hScore
                ? 'guest'
                : 'draw';
        update['finishReason'] = 'pass_limit';
        update['finishedAt'] = FieldValue.serverTimestamp();
        update['turnDeadlineAt'] = null;
      }
      tx.update(ref, update);
      _debugLog(
          'passTurn room=$roomCode passCount=$newCount next=$nextTurnUid finished=${newCount >= 4}');
    });
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
        'finishReason': 'forfeit',
        'finishedBy': uid,
        'finishedAt': FieldValue.serverTimestamp(),
      });
      Log.warn('MultiplayerService',
          'leaveRoom: uid=$uid forfeited room=$roomCode', null);
      _debugLog('leaveRoom room=$roomCode uid=$uid status=finished');
    } catch (e) {
      Log.warn('MultiplayerService', 'leaveRoom update failed', e);
    }
  }

  static List<Map<String, dynamic>> serializeBoard(WordBoard board) {
    return board.cells
        .where((c) => c.isLocked)
        .map((c) => {'r': c.row, 'c': c.column, 'l': c.letter})
        .toList();
  }
}
