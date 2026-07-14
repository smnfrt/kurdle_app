import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

class MultiplayerPrivacy {
  final bool chatEnabled;
  final Set<String> blockedUids;

  const MultiplayerPrivacy({
    required this.chatEnabled,
    required this.blockedUids,
  });

  factory MultiplayerPrivacy.fromData(Map<String, dynamic>? data) {
    if (data == null) {
      return const MultiplayerPrivacy(chatEnabled: true, blockedUids: {});
    }
    return MultiplayerPrivacy(
      chatEnabled: data['chatEnabled'] as bool? ?? true,
      blockedUids: Set<String>.from(data['blockedUids'] ?? const []),
    );
  }

  bool blocks(String uid) => blockedUids.contains(uid);
}

class ChatAccessStatus {
  final MultiplayerPrivacy me;
  final MultiplayerPrivacy opponent;
  final String myUid;
  final String opponentUid;

  const ChatAccessStatus({
    required this.me,
    required this.opponent,
    required this.myUid,
    required this.opponentUid,
  });

  bool get canSend =>
      me.chatEnabled &&
      opponent.chatEnabled &&
      !me.blocks(opponentUid) &&
      !opponent.blocks(myUid);

  bool get iBlockedOpponent => me.blocks(opponentUid);
  bool get opponentBlockedMe => opponent.blocks(myUid);
}

class MultiplayerPrivacyService {
  MultiplayerPrivacyService._();
  static final MultiplayerPrivacyService instance =
      MultiplayerPrivacyService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _privacy =>
      _db.collection('playerPrivacy');

  Stream<MultiplayerPrivacy> privacyStream(String uid) {
    return _privacy
        .doc(uid)
        .snapshots()
        .map((snap) => MultiplayerPrivacy.fromData(snap.data()));
  }

  Future<MultiplayerPrivacy> getPrivacy(String uid) async {
    final snap = await _privacy.doc(uid).get();
    return MultiplayerPrivacy.fromData(snap.data());
  }

  Stream<ChatAccessStatus> chatAccessStream({
    required String myUid,
    required String opponentUid,
  }) {
    late final StreamController<ChatAccessStatus> ctrl;
    StreamSubscription<MultiplayerPrivacy>? mySub;
    StreamSubscription<MultiplayerPrivacy>? opponentSub;
    MultiplayerPrivacy my =
        const MultiplayerPrivacy(chatEnabled: true, blockedUids: {});
    MultiplayerPrivacy opponent =
        const MultiplayerPrivacy(chatEnabled: true, blockedUids: {});

    void emit() {
      if (ctrl.isClosed) return;
      ctrl.add(ChatAccessStatus(
        me: my,
        opponent: opponent,
        myUid: myUid,
        opponentUid: opponentUid,
      ));
    }

    ctrl = StreamController<ChatAccessStatus>.broadcast(
      onListen: () {
        mySub = privacyStream(myUid).listen((value) {
          my = value;
          emit();
        });
        opponentSub = privacyStream(opponentUid).listen((value) {
          opponent = value;
          emit();
        });
        emit();
      },
      onCancel: () async {
        await mySub?.cancel();
        await opponentSub?.cancel();
      },
    );
    return ctrl.stream;
  }

  Future<bool> canPlayersInteract(String uidA, String uidB) async {
    final values = await Future.wait([getPrivacy(uidA), getPrivacy(uidB)]);
    return !values[0].blocks(uidB) && !values[1].blocks(uidA);
  }

  Future<void> setChatEnabled(String uid, bool enabled) async {
    await _privacy.doc(uid).set({
      'chatEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> blockPlayer({
    required String myUid,
    required String blockedUid,
  }) async {
    if (myUid == blockedUid) return;
    await _privacy.doc(myUid).set({
      'blockedUids': FieldValue.arrayUnion([blockedUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unblockPlayer({
    required String myUid,
    required String blockedUid,
  }) async {
    if (myUid == blockedUid) return;
    await _privacy.doc(myUid).set({
      'blockedUids': FieldValue.arrayRemove([blockedUid]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
