import 'dart:async';

import 'package:characters/characters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';

class MatchChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime? createdAt;
  final String type;
  final List<String> readBy;

  const MatchChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.createdAt,
    required this.type,
    required this.readBy,
  });

  factory MatchChatMessage.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return MatchChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Oyuncu',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      type: data['type'] as String? ?? 'text',
      readBy: List<String>.from(data['readBy'] ?? const []),
    );
  }
}

class MatchChatService {
  MatchChatService._();
  static final MatchChatService instance = MatchChatService._();

  static const int maxMessageLength = 300;

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _matches =>
      _db.collection('matches');

  Future<void> ensureMatch(MultiplayerRoom room) async {
    final guestUid = room.guestUid;
    if (guestUid == null || guestUid.isEmpty) return;
    final players = <String>[room.hostUid, guestUid];
    final ref = _matches.doc(room.roomCode);
    await ref.set({
      'players': players,
      'hostUid': room.hostUid,
      'guestUid': guestUid,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCounts': {
        room.hostUid: 0,
        guestUid: 0,
      },
    }, SetOptions(merge: true));
  }

  Stream<List<MatchChatMessage>> messagesStream(String matchId) {
    return _matches
        .doc(matchId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(120)
        .snapshots()
        .map((snap) => snap.docs.map(MatchChatMessage.fromDoc).toList());
  }

  Stream<int> unreadCountStream(String matchId, String uid) {
    return _matches.doc(matchId).snapshots().map((snap) {
      final data = snap.data();
      final unread = data?['unreadCounts'];
      if (unread is! Map) return 0;
      return unread[uid] as int? ?? 0;
    });
  }

  Future<void> sendMessage({
    required MultiplayerRoom room,
    required String senderId,
    required String senderName,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const MatchChatException('empty_message');
    }
    if (trimmed.characters.length > maxMessageLength) {
      throw const MatchChatException('message_too_long');
    }

    final guestUid = room.guestUid;
    if (guestUid == null || guestUid.isEmpty) {
      throw const MatchChatException('match_not_ready');
    }
    final players = <String>[room.hostUid, guestUid];
    if (!players.contains(senderId)) {
      throw const MatchChatException('not_match_player');
    }

    final otherUid = players.firstWhere((uid) => uid != senderId);
    final matchRef = _matches.doc(room.roomCode);
    final messageRef = matchRef.collection('messages').doc();

    await _db.runTransaction((tx) async {
      tx.set(
          matchRef,
          {
            'players': players,
            'hostUid': room.hostUid,
            'guestUid': guestUid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'lastMessage': trimmed,
            'lastMessageAt': FieldValue.serverTimestamp(),
            'lastMessageBy': senderId,
            'unreadCounts': {
              senderId: 0,
              otherUid: FieldValue.increment(1),
            },
          },
          SetOptions(merge: true));
      tx.set(messageRef, {
        'senderId': senderId,
        'senderName': senderName.trim().isEmpty ? 'Oyuncu' : senderName.trim(),
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'text',
        'readBy': [senderId],
      });
    });
  }

  Future<void> markRead(String matchId, String uid) async {
    final matchRef = _matches.doc(matchId);
    await matchRef.set({
      'unreadCounts': {uid: 0},
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> reportMessage({
    required String matchId,
    required String messageId,
    required String reporterId,
    required String reportedSenderId,
    required String text,
  }) async {
    if (reporterId == reportedSenderId) {
      throw const MatchChatException('cannot_report_self');
    }
    await _matches.doc(matchId).collection('reports').add({
      'messageId': messageId,
      'reporterId': reporterId,
      'reportedSenderId': reportedSenderId,
      'textPreview': text.characters.take(120).join(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

class MatchChatException implements Exception {
  final String code;

  const MatchChatException(this.code);

  @override
  String toString() => code;
}
