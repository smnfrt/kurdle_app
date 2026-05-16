import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _kBg       = Color(0xFF1A1A2E);
const _kSurface  = Color(0xFF16213E);
const _kPrimary  = Color(0xFF4CAF50);
const _kBubbleMe = Color(0xFF2D4A2D);
const _kBubbleAI = Color(0xFF1E2A3A);

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime time;

  const ChatMessage({required this.text, required this.isMe, required this.time});
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Merhaba! Kürmanci Scrabble hakkında soru sorabilirsin. 🎯',
      isMe: false,
      time: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ];

  static const List<String> _quickReplies = [
    'Nasıl puan kazanırım?',
    'Bonus kareler ne işe yarar?',
    'Kürmanci harfler neler?',
    'AI nasıl oynar?',
  ];

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _controller.clear();
    _focusNode.requestFocus();

    setState(() {
      _messages.add(ChatMessage(text: trimmed, isMe: true, time: DateTime.now()));
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: _autoReply(trimmed),
          isMe: false,
          time: DateTime.now(),
        ));
      });
      _scrollToBottom();
    });
  }

  String _autoReply(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('puan') || lower.contains('skor')) {
      return 'Kelime uzunluğu ve bonus kareler puanını belirler. 3W karesi tüm kelime puanını 3 katına çıkarır! ⭐';
    }
    if (lower.contains('bonus') || lower.contains('kare')) {
      return '3W=Üçlü Kelime, 2W=İkili Kelime, 3L=Üçlü Harf, 2L=İkili Harf. ★ merkez kare 2W görevi görür. 🎯';
    }
    if (lower.contains('harf') || lower.contains('alfabe') || lower.contains('kürmanci')) {
      return 'Kürmanci alfabesi: A, B, C, Ç, D, E, Ê, F, G, H, I, Î, J, K, L, M, N, O, P, Q, R, S, Ş, T, U, Û, V, W, X, Y, Z 🔤';
    }
    if (lower.contains('ai') || lower.contains('yapay')) {
      return 'AI her hamlesinde elindeki harflere en yüksek puanı veren kelimeyi arar. Özellikle bonus kareleri hedefler! 🤖';
    }
    if (lower.contains('ilk') || lower.contains('başlangıç')) {
      return 'İlk hamle merkez ★ kareden geçmeli. Bu kare 2W bonusu verir, iyi bir başlangıç için uzun kelime bul! 🌟';
    }
    return 'Anlıyorum! Oyun hakkında başka bir sorun var mı? Bonus kareler, kelime kuralları veya stratejiler hakkında yardımcı olabilirim. 😊';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: true,
      // Input bar — Scaffold.bottomNavigationBar klavyeyle otomatik kayar
      bottomNavigationBar: SafeArea(
        child: Container(
          color: _kSurface,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  cursorColor: _kPrimary,
                  textInputAction: TextInputAction.send,
                  onTap: () {
                    _focusNode.requestFocus();
                    SystemChannels.textInput.invokeMethod('TextInput.show');
                  },
                  decoration: InputDecoration(
                    hintText: 'Bir şey sor…',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.07),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.white12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Colors.white12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: _kPrimary.withValues(alpha: 0.6), width: 1.5),
                    ),
                  ),
                  onSubmitted: _send,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _kPrimary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _send(_controller.text),
                  child: const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // App bar
          Container(
            padding: EdgeInsets.fromLTRB(4, top + 8, 16, 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E2A3A), Color(0xFF2D3F52)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: _kPrimary.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.smart_toy_rounded, color: _kPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Oyun Asistanı',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Kürmanci Scrabble Yardımcısı',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),

          // Quick replies
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _quickReplies.length,
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _send(_quickReplies[i]),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    _quickReplies[i],
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _BubbleView(message: _messages[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _BubbleView extends StatelessWidget {
  final ChatMessage message;

  const _BubbleView({required this.message});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final timeStr =
        '${message.time.hour.toString().padLeft(2, '0')}:${message.time.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _kPrimary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(color: _kPrimary.withValues(alpha: 0.4)),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: _kPrimary, size: 14),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _kBubbleMe : _kBubbleAI,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 18),
                    ),
                    border: Border.all(
                      color: isMe
                          ? _kPrimary.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.07),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                  ),
                ),
                const SizedBox(height: 3),
                Text(timeStr, style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
