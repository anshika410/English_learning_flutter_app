import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/ella_theme.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'end_screen.dart';

const List<String> _scaffoldPills = [
  'Honestly, I also feel...',
  'What helps me is...',
  'Try not to...',
];

class _CaptionItem {
  final String text;
  final bool isElla;

  const _CaptionItem({required this.text, required this.isElla});
}

class ConversationScreen extends StatefulWidget {
  final String topic;

  const ConversationScreen({super.key, required this.topic});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen>
    with SingleTickerProviderStateMixin {
  bool _captionsEnabled = true;
  bool _isKeyboardMode = false;
  bool _hasUserSpokenThisTurn = false;

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _captionScrollCtrl = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  int _lastCaptionCount = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulseAnim = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().startConversationSession(
        topic: widget.topic,
      );
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _captionScrollCtrl.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() {
      _hasUserSpokenThisTurn = true;
      _isKeyboardMode = false;
    });
    _textFocusNode.unfocus();
    context.read<ChatProvider>().sendMessage(text);
  }

  void _handleMicTap() {
    final chat = context.read<ChatProvider>();
    if (!chat.isListening) {
      setState(() => _hasUserSpokenThisTurn = true);
    }
    chat.toggleListening();
  }

  void _goToEndScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EndScreen(topic: widget.topic, durationLabel: '4 min 12 sec'),
      ),
    );
  }

  bool get _showScaffoldPills => !_hasUserSpokenThisTurn;

  List<_CaptionItem> _buildCaptionItems(ChatProvider chat) {
    final items = <_CaptionItem>[];
    for (final msg in chat.messages) {
      if (msg.role == MessageRole.user) {
        items.add(_CaptionItem(text: msg.content, isElla: false));
      } else if (msg.role == MessageRole.assistant) {
        items.add(_CaptionItem(text: msg.content, isElla: true));
      }
    }
    if (chat.isListening) {
      items.add(
        _CaptionItem(
          text: chat.currentTranscript.isNotEmpty
              ? chat.currentTranscript
              : 'Listening…',
          isElla: false,
        ),
      );
    }
    return items;
  }

  void _maybeAutoScroll(int captionCount) {
    if (captionCount == _lastCaptionCount) return;
    _lastCaptionCount = captionCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_captionScrollCtrl.hasClients) return;
      _captionScrollCtrl.animateTo(
        _captionScrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardUp = bottomInset > 0;

    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildCenterArea(keyboardUp: keyboardUp)),
              if (_showScaffoldPills && !keyboardUp) _buildScaffoldPills(),
              _buildInputBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: EllaColors.neutralSurface,
                border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: EllaColors.neutralSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.topic,
                  style: const TextStyle(
                    fontFamily: 'Chillax',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: EllaColors.neutralPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: EllaColors.skyLightest,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Finding My Voice',
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.neutralPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _goToEndScreen,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: EllaColors.neutralSurface,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
              ),
              child: Text(
                'End',
                style: GoogleFonts.baloo2(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: EllaColors.neutralSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArea({required bool keyboardUp}) {
    return Consumer<ChatProvider>(
      builder: (_, chat, __) {
        final isPulsing = chat.isLoading || chat.isSpeaking || chat.isListening;
        if (isPulsing) {
          if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat();
        } else {
          _pulseCtrl.stop();
        }

        final captions = _buildCaptionItems(chat);
        _maybeAutoScroll(captions.length);

        final avatarSize = keyboardUp
            ? (captions.length >= 3 ? 104.0 : 120.0)
            : (_captionsEnabled ? 160.0 : 200.0);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isPulsing)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (_, __) => Transform.scale(
                        scale: _pulseAnim.value,
                        child: Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: EllaColors.skyMain.withValues(alpha: 0.35),
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: avatarSize,
                    height: avatarSize,
                    child: Image.asset(
                      'images/ella-neutral.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ],
              ),
              if (_captionsEnabled) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    controller: _captionScrollCtrl,
                    padding: const EdgeInsets.only(bottom: 10),
                    itemCount: captions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) => _CaptionBubble(
                      text: captions[index].text,
                      isElla: captions[index].isElla,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScaffoldPills() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _scaffoldPills.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: EllaColors.mangoDark,
                  offset: Offset(0, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Text(
              _scaffoldPills[i],
              style: GoogleFonts.baloo2(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: EllaColors.neutralSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: EllaColors.neutralBg,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: _isKeyboardMode ? _buildKeyboardRow() : _buildMicRow(),
    );
  }

  Widget _buildMicRow() {
    return Consumer<ChatProvider>(
      builder: (_, chat, __) {
        final isListening = chat.isListening;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isListening ? 'TAP MIC TO STOP' : 'TAP MIC TO SPEAK',
              style: GoogleFonts.inconsolata(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: EllaColors.neutralMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _isKeyboardMode = true);
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (mounted) _textFocusNode.requestFocus();
                        });
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: EllaColors.neutralSurface,
                          border: Border.all(
                            color: EllaColors.neutralBorder,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.keyboard_alt_outlined,
                          size: 22,
                          color: EllaColors.neutralSecondary,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: _handleMicTap,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isListening)
                            const _MicPulseRing(color: EllaColors.mangoMain),
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isListening
                                  ? EllaColors.mangoDark
                                  : EllaColors.mangoMain,
                              border: Border.all(
                                color: EllaColors.mangoDark,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: EllaColors.mangoDark,
                                  offset: isListening
                                      ? const Offset(0, 1)
                                      : const Offset(0, 5),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Icon(
                              isListening
                                  ? Icons.stop_rounded
                                  : Icons.mic_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _captionsEnabled = !_captionsEnabled),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _captionsEnabled
                              ? EllaColors.skyLightest
                              : EllaColors.neutralSurface,
                          border: Border.all(
                            color: _captionsEnabled
                                ? EllaColors.skyLight
                                : EllaColors.neutralBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          _captionsEnabled
                              ? Icons.subtitles_rounded
                              : Icons.subtitles_off_rounded,
                          size: 22,
                          color: _captionsEnabled
                              ? EllaColors.skyDark
                              : EllaColors.neutralSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKeyboardRow() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            setState(() => _isKeyboardMode = false);
            _textFocusNode.unfocus();
          },
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EllaColors.neutralSurface,
              border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: EllaColors.neutralSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _textCtrl,
            focusNode: _textFocusNode,
            textInputAction: TextInputAction.send,
            autofocus: true,
            onSubmitted: (_) => _handleSend(),
            style: GoogleFonts.baloo2(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: EllaColors.neutralPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Type your reply…',
              hintStyle: GoogleFonts.baloo2(
                fontSize: 15,
                color: EllaColors.neutralMuted,
              ),
              filled: true,
              fillColor: EllaColors.neutralSurface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: EllaColors.neutralBorder,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: EllaColors.neutralBorder,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: EllaColors.skyMain,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _handleSend,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EllaColors.mangoMain,
              border: Border.all(color: EllaColors.mangoDark, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: EllaColors.mangoDark,
                  offset: Offset(0, 5),
                  blurRadius: 0,
                ),
              ],
            ),
            child: const Icon(
              Icons.send_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _CaptionBubble extends StatelessWidget {
  final String text;
  final bool isElla;

  const _CaptionBubble({required this.text, required this.isElla});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isElla ? EllaColors.skyLightest : EllaColors.mangoLightest,
        borderRadius: isElla
            ? const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
            : const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
        border: Border.all(
          color: isElla ? EllaColors.skyLight : EllaColors.mangoLight,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isElla ? 'ZOE SAYS' : 'YOU SAY',
            style: GoogleFonts.inconsolata(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isElla ? EllaColors.skyDark : EllaColors.mangoDark,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: isElla
                ? GoogleFonts.kalam(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: EllaColors.skyDark,
                    height: 1.4,
                  )
                : GoogleFonts.baloo2(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: EllaColors.mangoDark,
                    height: 1.4,
                  ),
          ),
        ],
      ),
    );
  }
}

class _MicPulseRing extends StatefulWidget {
  final Color color;
  const _MicPulseRing({required this.color});

  @override
  State<_MicPulseRing> createState() => _MicPulseRingState();
}

class _MicPulseRingState extends State<_MicPulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = Tween<double>(
      begin: 1.0,
      end: 1.6,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 0.5,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Transform.scale(
        scale: _scale.value,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: _opacity.value),
          ),
        ),
      ),
    );
  }
}
