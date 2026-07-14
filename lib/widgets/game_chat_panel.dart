import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/route_transitions.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/match_chat_service.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
import 'package:kurdle_app/services/multiplayer_privacy_service.dart';
import 'package:kurdle_app/widgets/chat_screen.dart';

const _kChatBg = Color(0xFF0E1724);
const _kChatSurface = Color(0xFF162030);
const _kChatPrimary = Color(0xFF4CAF50);
const _kChatBlue = Color(0xFF64B5F6);
const _kChatError = Color(0xFFEF5350);

class GameChatPanel extends StatefulWidget {
  final MultiplayerRoom room;
  final String myUid;
  final String myName;

  const GameChatPanel({
    super.key,
    required this.room,
    required this.myUid,
    required this.myName,
  });

  static Future<void> show(
    BuildContext context, {
    required MultiplayerRoom room,
    required String myUid,
    required String myName,
  }) {
    return showAppModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: Duration(milliseconds: 150),
        reverseDuration: Duration(milliseconds: 110),
      ),
      builder: (_) => GameChatPanel(
        room: room,
        myUid: myUid,
        myName: myName,
      ),
    );
  }

  @override
  State<GameChatPanel> createState() => _GameChatPanelState();
}

class _GameChatPanelState extends State<GameChatPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    MatchChatService.instance.markRead(widget.room.roomCode, widget.myUid);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const [Color(0xFF132033), _kChatBg]
        : const [Color(0xFFF8FBFC), Color(0xFFE6EEF2)];
    final titleColor = isDark ? Colors.white : const Color(0xFF18242C);
    final mutedColor =
        isDark ? Colors.white.withValues(alpha: 0.52) : const Color(0xFF52636E);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Container(
          height: mq.size.height * 0.86,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bgGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.86),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.46 : 0.20),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Column(
            children: [
              _ChatSheetDragHandle(
                width: 44,
                color: mutedColor.withValues(alpha: 0.48),
                margin: const EdgeInsets.only(top: 12, bottom: 14),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kChatPrimary.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: _kChatPrimary.withValues(alpha: 0.38),
                        ),
                      ),
                      child: const Icon(Icons.forum_rounded,
                          color: _kChatPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            L.chat,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.room.roomCode,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.close_rounded, color: mutedColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.055)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFD6E1E7),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      color:
                          _kChatPrimary.withValues(alpha: isDark ? 0.22 : 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _kChatPrimary.withValues(alpha: 0.42)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    labelColor: isDark ? Colors.white : const Color(0xFF1F5E37),
                    unselectedLabelColor: mutedColor,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    tabs: [
                      Tab(
                        icon: const Icon(Icons.groups_rounded, size: 17),
                        text: L.current == AppLocale.tr
                            ? 'Oyuncu Sohbeti'
                            : 'Sohbeta Lîstikvan',
                      ),
                      Tab(
                        icon: const Icon(Icons.help_rounded, size: 17),
                        text: L.current == AppLocale.tr ? 'Yardım' : 'Alîkarî',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PlayerChatTab(
                      room: widget.room,
                      myUid: widget.myUid,
                      myName: widget.myName,
                    ),
                    const ChatScreen(embedded: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatSheetDragHandle extends StatelessWidget {
  final Color color;
  final double width;
  final EdgeInsetsGeometry margin;

  const _ChatSheetDragHandle({
    required this.color,
    this.width = 42,
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width + 32,
      height: 28,
      alignment: Alignment.center,
      margin: margin,
      child: Container(
        width: width,
        height: 4,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _PlayerChatTab extends StatefulWidget {
  final MultiplayerRoom room;
  final String myUid;
  final String myName;

  const _PlayerChatTab({
    required this.room,
    required this.myUid,
    required this.myName,
  });

  @override
  State<_PlayerChatTab> createState() => _PlayerChatTabState();
}

class _PlayerChatTabState extends State<_PlayerChatTab> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  late final Stream<List<MatchChatMessage>> _messagesStream;
  late final Stream<ChatAccessStatus>? _chatAccessStream;
  late final ValueNotifier<bool> _sending;
  DateTime? _lastMarkReadAt;

  @override
  void initState() {
    super.initState();
    _messagesStream =
        MatchChatService.instance.messagesStream(widget.room.roomCode);
    final opponentUid = _opponentUid;
    _chatAccessStream = opponentUid == null
        ? null
        : MultiplayerPrivacyService.instance.chatAccessStream(
            myUid: widget.myUid,
            opponentUid: opponentUid,
          );
    _sending = ValueNotifier<bool>(false);
    _markReadThrottled(force: true);
  }

  String? get _opponentUid {
    if (widget.room.hostUid == widget.myUid) return widget.room.guestUid;
    if (widget.room.guestUid == widget.myUid) return widget.room.hostUid;
    return null;
  }

  String get _opponentName {
    if (widget.room.hostUid == widget.myUid) {
      return widget.room.guestName ?? 'Oyuncu';
    }
    return widget.room.hostName;
  }

  @override
  void dispose() {
    _sending.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _markReadThrottled({bool force = false}) {
    final now = DateTime.now();
    if (!force &&
        _lastMarkReadAt != null &&
        now.difference(_lastMarkReadAt!) < const Duration(seconds: 6)) {
      return;
    }
    _lastMarkReadAt = now;
    MatchChatService.instance.markRead(widget.room.roomCode, widget.myUid);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending.value) return;
    _sending.value = true;
    _controller.clear();
    try {
      await MatchChatService.instance.sendMessage(
        room: widget.room,
        senderId: widget.myUid,
        senderName: widget.myName,
        text: text,
      );
      HapticFeedback.selectionClick();
      _scrollToBottom();
    } on MatchChatException catch (e) {
      if (_controller.text.isEmpty) _controller.text = text;
      _showError(_localizedError(e.code));
    } catch (_) {
      if (_controller.text.isEmpty) _controller.text = text;
      _showError(L.current == AppLocale.tr
          ? 'Mesaj gönderilemedi.'
          : 'Peyam nehat şandin.');
    } finally {
      if (mounted) _sending.value = false;
    }
  }

  String _localizedError(String code) {
    switch (code) {
      case 'empty_message':
        return L.current == AppLocale.tr
            ? 'Boş mesaj gönderilemez.'
            : 'Peyama vala nayê şandin.';
      case 'message_too_long':
        return L.current == AppLocale.tr
            ? 'Mesaj en fazla 300 karakter olabilir.'
            : 'Peyam herî zêde 300 tîp be.';
      case 'match_not_ready':
        return L.current == AppLocale.tr
            ? 'Sohbet maç başladıktan sonra açılır.'
            : 'Sohbet piştî destpêka maçê vedibe.';
      case 'chat_disabled_by_me':
        return L.current == AppLocale.tr
            ? 'Sohbetin kapalı. Mesaj göndermek için aç.'
            : 'Sohbeta te girtî ye. Ji bo şandinê veke.';
      case 'opponent_chat_disabled':
        return L.current == AppLocale.tr
            ? 'Rakibin sohbetini kapatmış.'
            : 'Hevrikê te sohbet girtî kiriye.';
      case 'you_blocked_player':
        return L.current == AppLocale.tr
            ? 'Bu oyuncuyu engellediğin için mesaj gönderemezsin.'
            : 'Te ev lîstikvan asteng kiriye; peyam nayê şandin.';
      case 'blocked_by_player':
        return L.current == AppLocale.tr
            ? 'Bu oyuncuya mesaj gönderemezsin.'
            : 'Tu nikarî ji vê lîstikvanê re peyam bişînî.';
      default:
        return L.current == AppLocale.tr
            ? 'Bu sohbete mesaj gönderemezsin.'
            : 'Tu nikarî li vê sohbetê peyam bişînî.';
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _kChatError,
      ),
    );
  }

  Future<void> _reportMessage(MatchChatMessage message) async {
    if (message.senderId == widget.myUid) return;
    HapticFeedback.selectionClick();
    try {
      await MatchChatService.instance.reportMessage(
        matchId: widget.room.roomCode,
        messageId: message.id,
        reporterId: widget.myUid,
        reportedSenderId: message.senderId,
        text: message.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L.current == AppLocale.tr
              ? 'Mesaj raporlandı.'
              : 'Peyam hat raporkirin.'),
          backgroundColor: _kChatPrimary,
        ),
      );
    } catch (_) {
      _showError(L.current == AppLocale.tr
          ? 'Mesaj raporlanamadı.'
          : 'Peyam nehat raporkirin.');
    }
  }

  Future<void> _toggleChat(bool enabled) async {
    try {
      await MultiplayerPrivacyService.instance
          .setChatEnabled(widget.myUid, enabled);
      HapticFeedback.selectionClick();
    } catch (_) {
      _showError(L.current == AppLocale.tr
          ? 'Sohbet tercihi güncellenemedi.'
          : 'Bijareya sohbetê nehat nûkirin.');
    }
  }

  Future<void> _toggleBlock(ChatAccessStatus access) async {
    final opponentUid = _opponentUid;
    if (opponentUid == null) return;
    if (!access.iBlockedOpponent) {
      final ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(L.current == AppLocale.tr
                  ? 'Oyuncuyu engelle'
                  : 'Lîstikvan asteng bike'),
              content: Text(L.current == AppLocale.tr
                  ? '$_opponentName ile sohbet kapanacak ve tekrar eşleşmeniz engellenecek.'
                  : 'Sohbet bi $_opponentName re digire û careke din hevdu nabînin.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(L.current == AppLocale.tr ? 'Vazgeç' : 'Betal'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                      L.current == AppLocale.tr ? 'Engelle' : 'Asteng bike'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
    }
    try {
      if (access.iBlockedOpponent) {
        await MultiplayerPrivacyService.instance.unblockPlayer(
          myUid: widget.myUid,
          blockedUid: opponentUid,
        );
      } else {
        await MultiplayerPrivacyService.instance.blockPlayer(
          myUid: widget.myUid,
          blockedUid: opponentUid,
        );
      }
      HapticFeedback.selectionClick();
    } catch (_) {
      _showError(L.current == AppLocale.tr
          ? 'Engelleme tercihi güncellenemedi.'
          : 'Bijareya astengkirinê nehat nûkirin.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBg =
        isDark ? Colors.white.withValues(alpha: 0.07) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFD6E1E7);
    final accessStream = _chatAccessStream;
    if (accessStream == null) {
      return Center(
        child: Text(
          L.current == AppLocale.tr
              ? 'Sohbet maç başladıktan sonra açılır.'
              : 'Sohbet piştî destpêka maçê vedibe.',
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF667681),
          ),
        ),
      );
    }
    return StreamBuilder<ChatAccessStatus>(
      stream: accessStream,
      builder: (context, accessSnap) {
        final access = accessSnap.data ??
            ChatAccessStatus(
              me: const MultiplayerPrivacy(
                  chatEnabled: true, blockedUids: <String>{}),
              opponent: const MultiplayerPrivacy(
                  chatEnabled: true, blockedUids: <String>{}),
              myUid: widget.myUid,
              opponentUid: _opponentUid ?? '',
            );
        final canSend = access.canSend;
        final disabledReason = _chatDisabledReason(access);
        return Column(
          children: [
            _ChatPrivacyBar(
              chatEnabled: access.me.chatEnabled,
              isBlocked: access.iBlockedOpponent,
              opponentName: _opponentName,
              onChatChanged: _toggleChat,
              onBlockTap: () => _toggleBlock(access),
            ),
            if (disabledReason != null)
              _ChatNotice(message: disabledReason, isDark: isDark),
            Expanded(
              child: StreamBuilder<List<MatchChatMessage>>(
                stream: _messagesStream,
                builder: (context, snap) {
                  final messages = snap.data ?? const <MatchChatMessage>[];
                  if (messages.isEmpty && !snap.hasError) {
                    return Center(
                      child: Text(
                        L.current == AppLocale.tr
                            ? 'Henüz mesaj yok'
                            : 'Hîn peyam tune',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.34)
                              : const Color(0xFF667681),
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Text(
                        L.current == AppLocale.tr
                            ? 'Sohbet yüklenemedi.'
                            : 'Sohbet nehat barkirin.',
                        style: const TextStyle(color: _kChatError),
                      ),
                    );
                  }
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _markReadThrottled());
                  return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    itemCount: messages.length,
                    itemBuilder: (_, i) {
                      final message = messages[messages.length - 1 - i];
                      return _PlayerBubble(
                        message: message,
                        isMe: message.senderId == widget.myUid,
                        onReport: message.senderId == widget.myUid
                            ? null
                            : () => _reportMessage(message),
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                decoration: BoxDecoration(
                  color: isDark ? _kChatSurface : const Color(0xFFF4F8FA),
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: canSend,
                        maxLength: MatchChatService.maxMessageLength,
                        minLines: 1,
                        maxLines: 4,
                        style: TextStyle(
                          color:
                              isDark ? Colors.white : const Color(0xFF18242C),
                          fontSize: 14,
                        ),
                        cursorColor: _kChatPrimary,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: canSend
                              ? (L.current == AppLocale.tr
                                  ? 'Mesaj yaz...'
                                  : 'Peyam binivîse...')
                              : (L.current == AppLocale.tr
                                  ? 'Sohbet kapalı'
                                  : 'Sohbet girtî ye'),
                          hintStyle: TextStyle(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.34)
                                : const Color(0xFF667681),
                          ),
                          filled: true,
                          fillColor: inputBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: borderColor),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(
                              color: _kChatPrimary.withValues(alpha: 0.65),
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: _sending,
                      builder: (_, sending, __) => AnimatedScale(
                        scale: sending ? 0.94 : 1,
                        duration: const Duration(milliseconds: 120),
                        curve: Curves.easeOutCubic,
                        child: Material(
                          color: sending
                              ? _kChatPrimary.withValues(alpha: 0.45)
                              : _kChatPrimary,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: sending || !canSend ? null : _send,
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: sending
                                  ? const Padding(
                                      padding: EdgeInsets.all(13),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _chatDisabledReason(ChatAccessStatus access) {
    if (!access.me.chatEnabled) {
      return L.current == AppLocale.tr
          ? 'Sohbetin kapalı. İstersen buradan tekrar açabilirsin.'
          : 'Sohbeta te girtî ye. Tu dikarî ji vir dîsa vekî.';
    }
    if (access.iBlockedOpponent) {
      return L.current == AppLocale.tr
          ? 'Bu oyuncuyu engelledin. Mesajlaşma ve yeniden eşleşme kapalı.'
          : 'Te ev lîstikvan asteng kiriye. Sohbet û hevhatin girtî ye.';
    }
    if (access.opponentBlockedMe) {
      return L.current == AppLocale.tr
          ? 'Bu oyuncuyla mesajlaşamazsın.'
          : 'Tu nikarî bi vî lîstikvanî re biaxivî.';
    }
    if (!access.opponent.chatEnabled) {
      return L.current == AppLocale.tr
          ? 'Rakibin sohbetini kapatmış.'
          : 'Hevrikê te sohbet girtî kiriye.';
    }
    return null;
  }
}

class _ChatPrivacyBar extends StatelessWidget {
  final bool chatEnabled;
  final bool isBlocked;
  final String opponentName;
  final ValueChanged<bool> onChatChanged;
  final VoidCallback onBlockTap;

  const _ChatPrivacyBar({
    required this.chatEnabled,
    required this.isBlocked,
    required this.opponentName,
    required this.onChatChanged,
    required this.onBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF18242C);
    final muted = isDark ? Colors.white60 : const Color(0xFF667681);
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.055)
            : const Color(0xFFF4F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFD6E1E7),
        ),
      ),
      child: Row(
        children: [
          Icon(
            chatEnabled
                ? Icons.mark_chat_read_rounded
                : Icons.speaker_notes_off_rounded,
            color: chatEnabled ? _kChatPrimary : muted,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              L.current == AppLocale.tr ? 'Sohbetim' : 'Sohbeta min',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          Switch.adaptive(
            value: chatEnabled,
            onChanged: onChatChanged,
            activeColor: _kChatPrimary,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onBlockTap,
            icon: Icon(
              isBlocked ? Icons.lock_open_rounded : Icons.block_rounded,
              size: 17,
            ),
            label: Text(
              isBlocked
                  ? (L.current == AppLocale.tr ? 'Aç' : 'Veke')
                  : (L.current == AppLocale.tr ? 'Engelle' : 'Asteng'),
            ),
            style: TextButton.styleFrom(
              foregroundColor: isBlocked ? _kChatPrimary : _kChatError,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatNotice extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ChatNotice({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _kChatError.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kChatError.withValues(alpha: 0.28)),
      ),
      child: Text(
        message,
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF7A2730),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PlayerBubble extends StatelessWidget {
  final MatchChatMessage message;
  final bool isMe;
  final VoidCallback? onReport;

  const _PlayerBubble({
    required this.message,
    required this.isMe,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final time = message.createdAt;
    final timeStr = time == null
        ? ''
        : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) _Avatar(name: message.senderName),
          if (!isMe) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.42)
                            : const Color(0xFF667681),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onReport,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isMe
                          ? LinearGradient(
                              colors: [
                                _kChatPrimary.withValues(
                                    alpha: isDark ? 0.34 : 0.22),
                                _kChatBlue.withValues(
                                    alpha: isDark ? 0.20 : 0.13),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isMe
                          ? null
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.075)
                              : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(17),
                        topRight: const Radius.circular(17),
                        bottomLeft: Radius.circular(isMe ? 17 : 5),
                        bottomRight: Radius.circular(isMe ? 5 : 17),
                      ),
                      border: Border.all(
                        color: isMe
                            ? _kChatPrimary.withValues(alpha: 0.35)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.07)
                                : const Color(0xFFD6E1E7)),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.16 : 0.07),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      message.text,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF18242C),
                        fontSize: 14,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.24)
                          : const Color(0xFF8A969E),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: _kChatBlue.withValues(alpha: 0.20),
        shape: BoxShape.circle,
        border: Border.all(color: _kChatBlue.withValues(alpha: 0.42)),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: _kChatBlue,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
