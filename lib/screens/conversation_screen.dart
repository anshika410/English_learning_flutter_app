import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/ella_theme.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import '../widgets/waveform_icon.dart';
import 'end_screen.dart';

// ─── Mascot State ─────────────────────────────────────────────────────────────

enum _MascotState { speaking, listening, thinking }

// ─── Scaffold pills ───────────────────────────────────────────────────────────

const List<String> _scaffoldPills = [
  'Honestly, I also feel...',
  'What helps me is...',
  'Try not to...',
];

// ─── Caption item ─────────────────────────────────────────────────────────────

class _CaptionItem {
  final String text;
  final bool isElla;

  const _CaptionItem({required this.text, required this.isElla});
}

// ─── Screen ───────────────────────────────────────────────────────────────────

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
  bool _didPrecacheMascotImages = false;
  bool _isLoadingSession = true;
  bool _didAutoEnd = false;
  String _headerTitle = '';
  final Stopwatch _sessionStopwatch = Stopwatch();

  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _captionScrollCtrl = ScrollController();
  final FocusNode _textFocusNode = FocusNode();

  int _lastCaptionCount = 0;

  @override
  void initState() {
    super.initState();
    _headerTitle = widget.topic.trim().isEmpty ? 'Talk to Zoe' : widget.topic;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chat = context.read<ChatProvider>();
      chat.setSttEngine(SttEngineType.continuous);
      final title = await chat.startConversationSession(topic: widget.topic);
      if (mounted) {
        setState(() {
          _headerTitle = title;
          _isLoadingSession = false;
        });
        _sessionStopwatch.start();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didPrecacheMascotImages) return;
    precacheImage(
      const AssetImage('assets/mascot-animations/speaking.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/mascot-animations/listening.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/mascot-animations/regular-thinking.webp'),
      context,
    );
    precacheImage(
      const AssetImage('assets/mascot-animations/juggling.webp'),
      context,
    );
    _didPrecacheMascotImages = true;
  }

  @override
  void dispose() {
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

  /// Count full exchanges: number of user messages sent.
  int _sessionExchanges(ChatProvider chat) {
    return chat.messages.where((m) => m.role == MessageRole.user).length;
  }

  SessionType _sessionTypeFromExchanges(int exchanges) {
    if (exchanges == 0) return SessionType.empty;
    if (exchanges < 5) return SessionType.partial;
    return SessionType.full;
  }

  String get _durationLabel {
    final s = _sessionStopwatch.elapsed.inSeconds;
    final min = s ~/ 60;
    final sec = s % 60;
    if (min == 0) return '${sec}s';
    return '${min}m ${sec}s';
  }

  void _showEndSheet(BuildContext context) {
    final chat = context.read<ChatProvider>();
    final exchanges = _sessionExchanges(chat);
    final sessionType = _sessionTypeFromExchanges(exchanges);
    final duration = _durationLabel;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EndSheet(
        sessionType: sessionType,
        onKeepTalking: () => Navigator.of(ctx).pop(),
        onEnd: () {
          Navigator.of(ctx).pop();
          final analysisFuture = chat.analyzeConversationEnd();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EndScreen(
                topic: _headerTitle,
                durationLabel: duration,
                sessionType: sessionType,
                quality: ConversationQuality.great,
                analysisFuture: analysisFuture,
                onTalkToZoe: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => ConversationScreen(topic: widget.topic),
                  ),
                ),
              ),
            ),
          );
        },
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

  _MascotState _mascotStateFrom(ChatProvider chat) {
    if (chat.isSpeaking) return _MascotState.speaking;
    if (chat.isLoading) return _MascotState.thinking;
    // Idle (waiting for mic tap) and actively listening both show listening animation
    return _MascotState.listening;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardUp = bottomInset > 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showEndSheet(context);
      },
      child: Scaffold(
        backgroundColor: EllaColors.neutralBg,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Consumer<ChatProvider>(
            builder: (_, chat, child) {
              // Auto-end: fire once after Zoe finishes speaking the closing line
              if (chat.conversationComplete && !chat.isSpeaking && !_didAutoEnd) {
                _didAutoEnd = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _showEndSheet(context);
                });
              }
              return child!;
            },
            child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fullHeight = constraints.maxHeight;
              final shrinkMascot = keyboardUp;

              return Stack(
                children: [
                  // Layer 1: Dashed grid background
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _DashedGridPainter()),
                    ),
                  ),

                  // Layer 2: Main content
                  Column(
                    children: [
                      _buildAppBar(),

                      // Mascot zone: expands to 70% when captions off (centred),
                      // 40% normal or 25% with keyboard when captions on
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        height: !_captionsEnabled
                            ? fullHeight * 0.70
                            : (shrinkMascot
                                ? fullHeight * 0.25
                                : fullHeight * 0.40),
                        child: Center(
                          child: _isLoadingSession
                              ? _buildLoadingMascot(shrinkMascot)
                              : Consumer<ChatProvider>(
                                  builder: (_, chat, _) => _ConversationMascot(
                                    mascotState: _mascotStateFrom(chat),
                                    size: !_captionsEnabled
                                        ? 240.0
                                        : (shrinkMascot ? 120.0 : 200.0),
                                  ),
                                ),
                        ),
                      ),

                      // Chat bubble list with top+bottom fade
                      Expanded(
                        child: Consumer<ChatProvider>(
                          builder: (_, chat, _) {
                            final captions = _buildCaptionItems(chat);
                            _maybeAutoScroll(captions.length);
                            if (!_captionsEnabled) return const SizedBox();
                            return ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback: (Rect bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.white,
                                    Colors.white,
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.06, 0.88, 1.0],
                                ).createShader(bounds);
                              },
                              child: RepaintBoundary(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: ListView.separated(
                                    controller: _captionScrollCtrl,
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      bottom: 16,
                                    ),
                                    itemCount: captions.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, index) =>
                                        _ConversationCaption(
                                          text: captions[index].text,
                                          isElla: captions[index].isElla,
                                        ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      if (_showScaffoldPills && !keyboardUp)
                        _buildScaffoldPills(),
                      _buildInputBar(),
                    ],
                  ),
                ],
              );
            },
          ),
        ), // Consumer
      ),        // SafeArea
    ),          // body: of Scaffold
  ),            // Scaffold child of PopScope
  );            // PopScope / return
  }

  Widget _buildLoadingMascot(bool shrinkMascot) {
    final size = shrinkMascot ? 120.0 : 200.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: EllaColors.zoeMintLight,
            boxShadow: [
              BoxShadow(
                color: EllaColors.neutralMuted.withValues(alpha: 0.40),
                offset: const Offset(0, 6),
                blurRadius: 0,
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/mascot-animations/juggling.webp',
              fit: BoxFit.cover,
            ),
          ),
        ),
        if (!shrinkMascot) ...[
          const SizedBox(height: 12),
          Text(
            'Preparing your conversation…',
            style: GoogleFonts.inconsolata(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: EllaColors.neutralMuted,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAppBar() {
    final topicLabel = _headerTitle.isEmpty ? 'Talk to Zoe' : _headerTitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              topicLabel,
              style: const TextStyle(
                fontFamily: 'Chillax',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: EllaColors.neutralPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => _showEndSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: EllaColors.errorSurface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                  bottomLeft: Radius.circular(20),
                ),
                border: Border.all(
                  color: EllaColors.errorLight,
                  width: 1.5,
                ),
              ),
              child: Text(
                'END',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: EllaColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScaffoldPills() {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _scaffoldPills.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: _isKeyboardMode ? _buildKeyboardRow() : _buildMicRow(),
    );
  }

  Widget _buildMicRow() {
    return Consumer<ChatProvider>(
      builder: (_, chat, _) {
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
                            child: isListening
                                ? const WaveformIcon()
                                : const Icon(
                                    Icons.mic_rounded,
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

// ─── Animated Mascot ─────────────────────────────────────────────────────────

class _ConversationMascot extends StatefulWidget {
  final _MascotState mascotState;
  final double size;

  const _ConversationMascot({
    required this.mascotState,
    required this.size,
  });

  @override
  State<_ConversationMascot> createState() => _ConversationMascotState();
}

class _ConversationMascotState extends State<_ConversationMascot> {
  // When idle (listening), we loop: listening 4s → juggling 4s → repeat
  bool _showJuggling = false;
  Timer? _idleTimer;

  static const _holdDuration = Duration(seconds: 4);

  @override
  void initState() {
    super.initState();
    if (widget.mascotState == _MascotState.listening) {
      _scheduleIdleStep();
    }
  }

  @override
  void didUpdateWidget(_ConversationMascot old) {
    super.didUpdateWidget(old);
    if (widget.mascotState != old.mascotState) {
      if (widget.mascotState == _MascotState.listening) {
        // Returned to idle — start from listening
        setState(() => _showJuggling = false);
        _scheduleIdleStep();
      } else {
        // AI is speaking/thinking — cancel loop, show correct asset
        _idleTimer?.cancel();
        _idleTimer = null;
        if (_showJuggling) setState(() => _showJuggling = false);
      }
    }
  }

  void _scheduleIdleStep() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_holdDuration, () {
      if (!mounted) return;
      setState(() => _showJuggling = !_showJuggling);
      _scheduleIdleStep();
    });
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    super.dispose();
  }

  String get _assetPath {
    if (widget.mascotState == _MascotState.speaking) {
      return 'assets/mascot-animations/speaking.webp';
    }
    if (widget.mascotState == _MascotState.thinking) {
      return 'assets/mascot-animations/regular-thinking.webp';
    }
    // Idle (listening) — alternates with juggling
    return _showJuggling
        ? 'assets/mascot-animations/juggling.webp'
        : 'assets/mascot-animations/listening.webp';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: EllaColors.zoeMintLight,
        boxShadow: [
          BoxShadow(
            color: EllaColors.neutralMuted.withValues(alpha: 0.40),
            offset: const Offset(0, 6),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(0, 3),
            blurRadius: 14,
          ),
        ],
      ),
      child: ClipOval(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              FadeTransition(opacity: animation, child: child),
          child: Image.asset(
            _assetPath,
            key: ValueKey<String>(_assetPath),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

// ─── Conversation Caption Bubble ─────────────────────────────────────────────

class _ConversationCaption extends StatelessWidget {
  final String text;
  final bool isElla;

  const _ConversationCaption({required this.text, required this.isElla});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isElla ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        child: Container(
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
            boxShadow: [
              BoxShadow(
                color: isElla ? EllaColors.skyDark : EllaColors.mangoDark,
                offset: const Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                        fontWeight: FontWeight.w400,
                        color: EllaColors.skyDark,
                        height: 1.4,
                      )
                    : GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: EllaColors.mangoDark,
                        height: 1.4,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mic Pulse Ring ───────────────────────────────────────────────────────────

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
      builder: (_, _) => Transform.scale(
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

// ─── End Sheet ───────────────────────────────────────────────────────────────

class _EndSheet extends StatelessWidget {
  final SessionType sessionType;
  final VoidCallback onKeepTalking;
  final VoidCallback onEnd;

  const _EndSheet({
    required this.sessionType,
    required this.onKeepTalking,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: EllaColors.neutralBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: EllaColors.neutralBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            const Text(
              'Leaving the Conversation?',
              style: TextStyle(
                fontFamily: 'Chillax',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: EllaColors.neutralPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "I'm available to talk whenever you feel like it again",
              style: GoogleFonts.baloo2(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: EllaColors.neutralSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // CTAs: END on left, KEEP TALKING on right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // End button — solid red
                GestureDetector(
                  onTap: onEnd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: EllaColors.error,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                        bottomLeft: Radius.circular(20),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: EllaColors.roseDark,
                          offset: Offset(0, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      'END',
                      style: GoogleFonts.baloo2(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Keep talking — mango primary
                _KeepTalkingButton(onTap: onKeepTalking),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepTalkingButton extends StatefulWidget {
  final VoidCallback onTap;
  const _KeepTalkingButton({required this.onTap});

  @override
  State<_KeepTalkingButton> createState() => _KeepTalkingButtonState();
}

class _KeepTalkingButtonState extends State<_KeepTalkingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final shadowOffset = _pressed ? const Offset(0, 1) : const Offset(0, 4);
    final translateY = _pressed ? 3.0 : 0.0;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        curve: Curves.ease,
        transform: Matrix4.translationValues(0, translateY, 0),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [EllaColors.mangoTop, EllaColors.mangoMain],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(4),
            bottomLeft: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: EllaColors.mangoDark,
              offset: shadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          'KEEP TALKING',
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

// ─── Dashed Grid Background ───────────────────────────────────────────────────

class _DashedGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = EllaColors.neutralBorder.withValues(alpha: 0.50)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 28.0;
    const dashLen = 3.0;
    const gapLen = 5.0;

    for (double x = 0; x <= size.width; x += spacing) {
      _drawDashedLine(
        canvas,
        paint,
        Offset(x, 0),
        Offset(x, size.height),
        dashLen,
        gapLen,
      );
    }
    for (double y = 0; y <= size.height; y += spacing) {
      _drawDashedLine(
        canvas,
        paint,
        Offset(0, y),
        Offset(size.width, y),
        dashLen,
        gapLen,
      );
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Paint paint,
    Offset start,
    Offset end,
    double dashLen,
    double gapLen,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = Offset(dx, dy).distance;
    if (len == 0) return;
    final normX = dx / len;
    final normY = dy / len;
    double dist = 0;
    while (dist < len) {
      final dashEnd = (dist + dashLen).clamp(0.0, len);
      canvas.drawLine(
        Offset(start.dx + normX * dist, start.dy + normY * dist),
        Offset(start.dx + normX * dashEnd, start.dy + normY * dashEnd),
        paint,
      );
      dist += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(_DashedGridPainter old) => false;
}
