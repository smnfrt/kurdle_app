import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kurdle_app/services/app_locale.dart';
import 'package:kurdle_app/services/match_chat_service.dart';
import 'package:kurdle_app/services/multiplayer_service.dart';
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
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

    return AnimatedPadding(
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
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 14),
              decoration: BoxDecoration(
                color: mutedColor.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(2),
              ),
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
                    onPressed: () => Navigator.pop(context),
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
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await MatchChatService.instance.sendMessage(
        room: widget.room,
        senderId: widget.myUid,
        senderName: widget.myName,
        text: text,
      );
      _controller.clear();
      HapticFeedback.selectionClick();
      _scrollToBottom();
    } on MatchChatException catch (e) {
      _showError(_localizedError(e.code));
    } catch (_) {
      _showError(L.current == AppLocale.tr
          ? 'Mesaj gönderilemedi.'
          : 'Peyam nehat şandin.');
    } finally {
      if (mounted) setState(() => _sending = false);
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
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
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<MatchChatMessage>>(
            stream:
                MatchChatService.instance.messagesStream(widget.room.roomCode),
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
              WidgetsBinding.instance.addPostFrameCallback((_) {
                MatchChatService.instance
                    .markRead(widget.room.roomCode, widget.myUid);
              });
              return ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                itemCount: messages.length,
                itemBuilder: (_, i) => _PlayerBubble(
                  message: messages[i],
                  isMe: messages[i].senderId == widget.myUid,
                ),
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
                    maxLength: MatchChatService.maxMessageLength,
                    minLines: 1,
                    maxLines: 4,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF18242C),
                      fontSize: 14,
                    ),
                    cursorColor: _kChatPrimary,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: L.current == AppLocale.tr
                          ? 'Mesaj yaz...'
                          : 'Peyam binivîse...',
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
                Material(
                  color: _sending
                      ? _kChatPrimary.withValues(alpha: 0.45)
                      : _kChatPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _sending ? null : _send,
                    child: const SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerBubble extends StatelessWidget {
  final MatchChatMessage message;
  final bool isMe;

  const _PlayerBubble({required this.message, required this.isMe});

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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe
                        ? _kChatPrimary.withValues(alpha: isDark ? 0.28 : 0.18)
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
