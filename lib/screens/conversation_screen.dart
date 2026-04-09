import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/ella_theme.dart';
import '../models/chat_message.dart';
import '../providers/chat_provider.dart';
import 'end_screen.dart';

// ─── Scaffold pills shown at A1/A2 levels ─────────────────────────────────────

const List<String> _scaffoldPills = [
  'Honestly, I also feel...',
  'What helps me is...',
  'Try not to...',
];

// ─── ConversationScreen ───────────────────────────────────────────────────────

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

  // Pulse animation for Ella's avatar when speaking/loading
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().initialize();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _textCtrl.dispose();
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
    context.read<ChatProvider>().sendMessage(text);
  }

  void _handleMicTap() {
    final chat = context.read<ChatProvider>();
    if (!chat.isListening) {
      setState(() => _hasUserSpokenThisTurn = true);
    } else {
      // When stopping, next Ella turn will reset this
    }
    chat.toggleListening();
  }

  void _goToEndScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EndScreen(
          topic: widget.topic,
          durationLabel: '4 min 12 sec',
        ),
      ),
    );
  }

  bool get _showScaffoldPills => !_hasUserSpokenThisTurn;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildCenterArea()),
            if (_showScaffoldPills) _buildScaffoldPills(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── App bar ──────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          // Back button
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
          // Topic + level
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.topic,
                  style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: EllaColors.neutralPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: EllaColors.skyLightest,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Finding My Voice',
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: EllaColors.skyDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // End conversation button
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

  // ── Center area: avatar + captions ──────────────────────────────────────────

  Widget _buildCenterArea() {
    return Consumer<ChatProvider>(
      builder: (ctx, chat, child) {
        final isPulsing = chat.isLoading || chat.isSpeaking || chat.isListening;
        if (!chat.isLoading && !chat.isSpeaking && !chat.isListening) {
          _pulseCtrl.stop();
        } else {
          if (!_pulseCtrl.isAnimating) _pulseCtrl.repeat();
        }

        // Determine caption content
        String? captionText;
        bool captionIsElla = true;
        if (chat.isListening && chat.currentTranscript.isNotEmpty) {
          captionText = chat.currentTranscript;
          captionIsElla = false;
        } else if (chat.isListening) {
          captionText = 'Listening…';
          captionIsElla = false;
        } else if (chat.messages.isNotEmpty) {
          final last = chat.messages.last;
          captionText = last.content;
          captionIsElla = last.role != MessageRole.user;
        }

        final avatarSize = _captionsEnabled ? 160.0 : 200.0;

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ella avatar with optional pulse ring
              Stack(
                alignment: Alignment.center,
                children: [
                  if (isPulsing)
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context2, child2) => Transform.scale(
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

              // Caption bubble
              if (_captionsEnabled && captionText != null) ...[
                const SizedBox(height: 20),
                _CaptionBubble(text: captionText, isElla: captionIsElla),
              ],
            ],
          ),
        );
      },
    );
  }

  // ── Scaffold pills ───────────────────────────────────────────────────────────

  Widget _buildScaffoldPills() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _scaffoldPills.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
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

  // ── Input bar ────────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      color: EllaColors.neutralBg,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: _isKeyboardMode ? _buildKeyboardRow() : _buildMicRow(),
    );
  }

  Widget _buildMicRow() {
    return Consumer<ChatProvider>(
      builder: (ctx, chat, child) {
        final isListening = chat.isListening;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TAP MIC TO SPEAK',
              style: GoogleFonts.inconsolata(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: EllaColors.neutralMuted,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Keyboard icon
                GestureDetector(
                  onTap: () => setState(() => _isKeyboardMode = true),
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
                const SizedBox(width: 24),
                // Mic button
                GestureDetector(
                  onTap: _handleMicTap,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isListening)
                        _MicPulseRing(color: EllaColors.mangoMain),
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isListening
                              ? EllaColors.mangoDark
                              : EllaColors.mangoMain,
                          border: Border.all(color: EllaColors.mangoDark, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: EllaColors.mangoDark,
                              offset: isListening
                                  ? const Offset(1, 1)
                                  : const Offset(3, 3),
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
                const SizedBox(width: 24),
                // CC (captions) toggle
                GestureDetector(
                  onTap: () => setState(() => _captionsEnabled = !_captionsEnabled),
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
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildKeyboardRow() {
    return Row(
      children: [
        // Back to mic
        GestureDetector(
          onTap: () => setState(() => _isKeyboardMode = false),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: EllaColors.neutralSurface,
              border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
            ),
            child: const Icon(
              Icons.mic_rounded,
              size: 22,
              color: EllaColors.neutralSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Text field
        Expanded(
          child: TextField(
            controller: _textCtrl,
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
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button
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
                  offset: Offset(2, 2),
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

// ─── Caption Bubble ───────────────────────────────────────────────────────────

class _CaptionBubble extends StatelessWidget {
  final String text;
  final bool isElla;

  const _CaptionBubble({required this.text, required this.isElla});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isElla ? EllaColors.skyLightest : EllaColors.mangoLightest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isElla ? EllaColors.skyLight : EllaColors.mangoLight,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isElla ? 'ELLA SAYS' : 'YOU SAY',
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
      ),
    );
  }
}

// ─── Mic pulse ring ───────────────────────────────────────────────────────────

class _MicPulseRing extends StatefulWidget {
  final Color color;
  const _MicPulseRing({required this.color});

  @override
  State<_MicPulseRing> createState() => _MicPulseRingState();
}

class _MicPulseRingState extends State<_MicPulseRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _scale = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _opacity = Tween<double>(begin: 0.5, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
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
      builder: (ctx, child) => Transform.scale(
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
