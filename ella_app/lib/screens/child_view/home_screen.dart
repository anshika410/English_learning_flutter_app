// Home / Talk screen — Figma "Learning Flow — Homescreen".
// A botanical garden scene (HomeSceneBackground): sky→green gradient with hills,
// bush, daisies and grass. Garden / Profile shortcuts sit in the top corners,
// the sprout mascot "Zoe" and her "Last time" recall bubble sit centre, a
// swipeable topic carousel (TopicCarousel) lets the child pick a topic, and the
// selected-topic CTA ("Let's Talk About …") anchors the bottom. Recap + topics
// come live from the memory API's next_topics; the carousel only SELECTS a topic
// — only the CTA starts a session, sending the topic name to POST /session.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

import '../../core/app_toast.dart';
import '../../core/offline_alert_popup.dart';
import '../../core/ella_smooth_shape.dart';
import '../../core/text_styles.dart';
import '../../core/theme_colors.dart';
import '../../models/child_memory.dart';
import '../../models/conversation_feedback.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/service_providers.dart';
import '../../services/analytics_service.dart';
import '../../services/sounds.dart';
import 'session_screen.dart';
import 'topic_launcher.dart';
import 'widgets/ella_primary_button.dart';
import 'widgets/home_scene_background.dart';
import 'widgets/home_shortcut_header.dart';
import 'widgets/shake.dart';
import 'widgets/speaker_dot_button.dart';
import 'widgets/topic_carousel.dart';
import 'widgets/zoe_mascot.dart';
import 'chat_bubble.dart';
import 'widgets/network_error_view.dart';

// The child's display name. No name field exists on MemoryState yet (childId is
// 'demo'), so this is a swappable placeholder matching the design demo until a
// real profile name is wired through.
const String kHomeChildName = 'Maya';

const String _kVoiceIcon = 'assets/homescreen/new/UserSound.svg'; // CTA

// Mascot footprint from the Figma frame (150.55-wide in a 430-wide artboard).
const double _kMascotWidthFactor = 150.55 / 430;

class HomeScreen extends ConsumerWidget {
  final ValueChanged<ConversationEndContext>? onConversationEnded;
  final VoidCallback? onOpenGarden;
  final VoidCallback? onOpenProfile;

  const HomeScreen({
    super.key,
    this.onConversationEnded,
    this.onOpenGarden,
    this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(chatProvider);
    return chatAsync.when(
      data: (s) => _HomeBody(
        memory: s.memory,
        onConversationEnded: onConversationEnded,
        onOpenGarden: onOpenGarden,
        onOpenProfile: onOpenProfile,
      ),
      loading: () => _HomeBody(
        memory: null,
        onConversationEnded: onConversationEnded,
        onOpenGarden: onOpenGarden,
        onOpenProfile: onOpenProfile,
      ),
      error: (e, _) =>
          NetworkErrorView(onRetry: () => ref.invalidate(chatProvider)),
    );
  }
}

class _HomeBody extends ConsumerStatefulWidget {
  final MemoryState? memory;
  final ValueChanged<ConversationEndContext>? onConversationEnded;
  final VoidCallback? onOpenGarden;
  final VoidCallback? onOpenProfile;

  const _HomeBody({
    required this.memory,
    required this.onConversationEnded,
    required this.onOpenGarden,
    required this.onOpenProfile,
  });

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  // The topic the CTA will start. Null means "use the server's recommended".
  // Tapping an alternative chip or picking one in See More sets this; it never
  // starts a session — only the CTA does.
  TopicChoice? _selectedTopic;
  bool _isStarting =
      false; // guard against double-tap creating duplicate sessions

  int _highlightStart = -1;
  int _highlightEnd = -1;
  bool _speaking = false;
  StreamSubscription? _ttsProgressSub;
  StreamSubscription? _ttsDoneSub;

  @override
  void initState() {
    super.initState();
    final nativeTts = ref.read(nativeTtsProvider);
    _ttsProgressSub = nativeTts.progressStream.listen((event) {
      if (mounted && _speaking) {
        setState(() {
          _highlightStart = event.start;
          _highlightEnd = event.end;
        });
      }
    });
    _ttsDoneSub = nativeTts.doneStream.listen((_) {
      if (mounted) {
        setState(() {
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
    });
  }

  @override
  void dispose() {
    _ttsProgressSub?.cancel();
    _ttsDoneSub?.cancel();
    super.dispose();
  }

  MemoryState? get _memory => widget.memory;

  // Server recommendation and the alternatives shown as chips.
  TopicChoice? get _recommended => _memory?.nextTopics.recommended;

  List<TopicChoice> get _alternatives =>
      _memory?.nextTopics.alternatives ?? const [];

  // The effective selection driving the CTA (explicit pick, else recommended).
  TopicChoice? get _selected {
    final explicit = _selectedTopic;
    final recommended = _recommended;
    if (explicit != null &&
        [
          ?recommended,
          ..._alternatives,
        ].any((topic) => topic.name == explicit.name)) {
      return explicit;
    }
    return recommended;
  }

  // Server-authored recap line ("Last time…"), shown verbatim. Empty until the
  // API provides it, in which case the card shows its first-chat fallback.
  String get _recap {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;
    if (!isOnline) {
      final name =
          ref.watch(onboardingProvider).valueOrNull?.firstName ??
          kHomeChildName;
      return "Hey $name, I'm having trouble connecting to the internet right now!";
    }
    return _memory?.lastTimeRecap ?? '';
  }

  void _selectTopic(TopicChoice topic) {
    ref.read(audioProvider).playSfx(Sounds.topic);
    setState(() {
      _selectedTopic = topic;
    });
  }

  // The garden needs live data (it fetches from the API), so opening it offline
  // would only land on the error view. Block navigation and surface a snackbar
  // instead so the offline state stays on the calmer Home screen.
  void _handleOpenGarden() {
    final isOnline = ref.read(connectivityProvider).valueOrNull ?? true;
    if (!isOnline) {
      showEllaErrorToast(
        context,
        "You're offline. Connect to the internet to visit your garden",
      );
      return;
    }
    widget.onOpenGarden?.call();
  }

  // Replays the "Last time" recap aloud. Speaks the same fallback line that the
  // card shows when the server hasn't sent a recap yet. A no-op while TTS is
  // already speaking (placement-flow behavior), so taps can't stack utterances.
  Future<void> _speakRecap() async {
    final tts = ref.read(ttsProvider);
    if (_speaking) {
      await tts.stop();
      if (mounted) {
        setState(() {
          _speaking = false;
          _highlightStart = -1;
          _highlightEnd = -1;
        });
      }
      return;
    }
    final text = _recap.trim().isNotEmpty
        ? _recap.trim()
        : 'Ready for your first chat?';
    setState(() {
      _speaking = true;
      _highlightStart = -1;
      _highlightEnd = -1;
    });
    AnalyticsService.logTodayRecapOpened();
    AnalyticsService.logDailyRecapOpened();
    try {
      await tts.speak(text);
    } catch (_) {
      if (mounted) {
        setState(() {
          _speaking = false;
        });
      }
    }
  }

  // Topics the carousel cycles through: the server's recommended first, then the
  // alternatives, de-duplicated by name. The carousel loops over this list.
  List<TopicChoice> get _carouselTopics {
    final ordered = <TopicChoice>[];
    final seen = <String>{};
    void add(TopicChoice? t) {
      if (t == null || t.name.isEmpty || !seen.add(t.name)) return;
      ordered.add(t);
    }

    add(_recommended);
    for (final t in _alternatives) {
      add(t);
    }
    return ordered;
  }

  Future<void> _startSelected() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final sel = _selected;
      if (sel != null && sel.name.isNotEmpty) {
        // The topic NAME (not the label) is what the backend expects.
        await startTopic(
          context,
          ref,
          sel,
          onConversationEnded: widget.onConversationEnded,
        );
        return;
      }
      // No recommendation yet — fall back to the engine's own topic pick.
      final chatState = ref.read(chatProvider);
      if (chatState.hasValue && chatState.requireValue.sessionEnded) {
        await ref.read(chatProvider.notifier).nextChat();
      }
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SessionScreen(onEnded: widget.onConversationEnded),
        ),
      );
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    // Keep the CTA tappable even while memory is still loading so it doesn't
    // visibly flip from disabled→enabled on launch; _startSelected safely no-ops
    // until chatProvider has a value. The label fills in once the topic loads.
    // The CTA shows the short label (server-authored) — the full name is only
    // used for POST /session.
    final selected = _selected;
    final selectedLabel = selected?.display ?? '';
    final ctaLabel = selectedLabel.isNotEmpty
        ? "Let's Talk About $selectedLabel"
        : "Let's Talk";

    final topics = _carouselTopics;

    final mascotW = (MediaQuery.of(context).size.width * _kMascotWidthFactor)
        .clamp(128.0, 168.0);

    return HomeSceneBackground(
      child: SafeArea(
        // 24px side gutters and a 24px bottom margin under the CTA.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              HomeShortcutHeader(
                onOpenProfile: widget.onOpenProfile,
                onOpenGarden: _handleOpenGarden,
              ),
              // Upper group (mascot + recap bubble + topic carousel), centred in
              // the space above the CTA; scrolls on short screens. The
              // ConstrainedBox + centred Column genuinely centres the content
              // (a plain Center around a SingleChildScrollView would top-align it).
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        key: const ValueKey('home-upper-content'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          ZoeMascot(
                            key: const ValueKey('home-zoe-mascot'),
                            mode: !isOnline
                                ? ZoeMascotMode.sleep
                                : ZoeMascotMode.listening,
                            size: mascotW,
                            reducedMotion: MediaQuery.of(
                              context,
                            ).disableAnimations,
                          ),
                          // The recap bubble itself starts 14px below the
                          // speaker-dot stack, leaving a visible 24px gap
                          // from Zoe to the bubble border.
                          const SizedBox(height: 10),
                          _LastTimeCard(
                            recap: _recap,
                            onSpeak: _speakRecap,
                            highlightStart: _highlightStart,
                            highlightEnd: _highlightEnd,
                            speaking: _speaking,
                          ),
                          const SizedBox(height: 24),
                          if (topics.isNotEmpty)
                            TopicCarousel(
                              // A fresh controller (and initial centre) whenever
                              // the available topic set changes.
                              key: ValueKey(
                                topics.map((t) => t.name).join('|'),
                              ),
                              topics: topics,
                              selected: _selected,
                              onSelect: _selectTopic,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom group — the selected-topic CTA.
              const SizedBox(height: 16),
              // Short wobble whenever the selected topic changes.
              ShakeOnChange(
                trigger: selected?.name ?? '',
                child: EllaPrimaryButton(
                  key: const ValueKey('home-talk-cta'),
                  label: ctaLabel,
                  labelChild: _TalkAboutCtaLabel(topicLabel: selectedLabel),
                  leading: SvgPicture.asset(
                    _kVoiceIcon,
                    width: 22,
                    height: 22,
                    colorFilter: const ColorFilter.mode(
                      EllaColors.onPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  height: 60,
                  playTapClickSound: false,
                  backgroundColor: isOnline ? null : Colors.grey[400],
                  edgeColor: isOnline ? null : Colors.grey[600],
                  onTap: isOnline
                      ? _startSelected
                      : () {
                          ref.read(audioProvider).playSfx(Sounds.error);
                          OfflineAlertPopup.show(context);
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TalkAboutCtaLabel extends StatelessWidget {
  final String topicLabel;

  const _TalkAboutCtaLabel({required this.topicLabel});

  static const String _prefix = 'Talk about';

  TextStyle _style() {
    return EllaTextStyles.button.copyWith(
      color: EllaColors.onPrimary,
      height: 1.15,
    );
  }

  bool _fitsOneLine(BuildContext context, String text, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: _style()),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    final style = _style();
    final topic = topicLabel.trim();
    if (topic.isEmpty) {
      return Text(
        'Start Talking',
        textAlign: TextAlign.center,
        maxLines: 1,
        style: style,
      );
    }

    final fullLabel = '$_prefix $topic';
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_fitsOneLine(context, fullLabel, constraints.maxWidth)) {
          return Text(
            fullLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            style: style,
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _prefix,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: style,
            ),
            SizedBox(
              width: constraints.maxWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  topic,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: style,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── "Last time" recall card ─────────────────────────────────────────────────

class _LastTimeCard extends StatelessWidget {
  // Server-authored recap text (memory.last_time_recap). Empty on a first chat
  // or before the API provides it, when the friendly fallback is shown instead.
  final String recap;

  /// Replays the recap aloud (TTS). Powers the speaker dot on the card, the
  /// same control that straddles Zoe's chat bubble.
  final VoidCallback onSpeak;
  final int highlightStart;
  final int highlightEnd;
  final bool speaking;

  const _LastTimeCard({
    required this.recap,
    required this.onSpeak,
    this.highlightStart = -1,
    this.highlightEnd = -1,
    this.speaking = false,
  });

  @override
  Widget build(BuildContext context) {
    final body = recap.trim().isNotEmpty
        ? recap.trim()
        : 'Ready for your first chat?';

    final card = Container(
      key: const ValueKey('home-last-time-bubble'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: ellaSmoothDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: EllaColors.info, width: 2),
      ),
      child: TypewriterText(
        text: body,
        style: EllaTextStyles.bodySemibold,
        highlightStart: highlightStart,
        highlightEnd: highlightEnd,
        animate: false,
      ),
    );

    // Speaker dot straddling the top-right border — identical control to Zoe's
    // chat bubble. Top padding keeps the overhanging dot inside the Stack's
    // bounds so it stays tappable.
    return Stack(
      key: const ValueKey('home-last-time-card'),
      clipBehavior: Clip.none,
      children: [
        Padding(padding: const EdgeInsets.only(top: 14), child: card),
        Positioned(
          top: 0,
          right: 10,
          child: SpeakerDotButton(active: speaking, onTap: onSpeak),
        ),
      ],
    );
  }
}
