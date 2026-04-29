import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/focus_settings.dart';
import '../providers/chat_provider.dart';
import '../theme/ella_responsive.dart';
import '../theme/ella_theme.dart';
import 'onboarding_screen.dart';

// ─── Mock / fallback profile data ────────────────────────────────────────────

const _mockEmail = 'test@navgurukul.org';

bool _isBelowB1(String level) => level == 'A1' || level == 'A2';

String _friendlyLevelLabel(String? level) {
  switch ((level ?? '').toUpperCase()) {
    case 'A1':
      return 'First Words';
    case 'B1':
      return 'Speaking Freely';
    case 'B2':
      return 'Almost Fluent';
    case 'C1':
      return 'Fluent';
    case 'A2':
    default:
      return 'Finding My Voice';
  }
}

// ─── ProfileScreen ────────────────────────────────────────────────────────────

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(
    BuildContext context,
    ChatProvider provider,
  ) async {
    Future<void> logout() async {
      await provider.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (_) => false,
        );
      }
    }

    if (EllaResponsive.isWide(context)) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: _LogoutSheetContent(
                showDragHandle: false,
                onStay: () => Navigator.of(dialogContext).pop(),
                onLogout: () async {
                  Navigator.of(dialogContext).pop();
                  await logout();
                },
              ),
            ),
          ),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _LogoutSheet(
        onStay: () => Navigator.of(sheetContext).pop(),
        onLogout: () async {
          Navigator.of(sheetContext).pop();
          await logout();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final level = provider.userLevel ?? 'A2';
    final showFocusSettings = !_isBelowB1(level);
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: _ProfileHeader(
        provider: provider,
        showFocusSettings: showFocusSettings,
        onLogout: () => _confirmLogout(context, provider),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatefulWidget {
  final ChatProvider provider;
  final bool showFocusSettings;
  final VoidCallback onLogout;
  const _ProfileHeader({
    required this.provider,
    required this.showFocusSettings,
    required this.onLogout,
  });

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  late final ValueNotifier<String> _nameNotifier;
  late final ValueNotifier<String> _ageNotifier;
  late final ValueNotifier<String> _locationNotifier;
  late final ValueNotifier<String> _emailNotifier;

  @override
  void initState() {
    super.initState();
    _nameNotifier = ValueNotifier(widget.provider.userName ?? 'You');
    _ageNotifier = ValueNotifier(widget.provider.userAge ?? '—');
    _locationNotifier = ValueNotifier(widget.provider.userLocation ?? '—');
    _emailNotifier = ValueNotifier(_mockEmail);
  }

  @override
  void didUpdateWidget(_ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _nameNotifier.value = widget.provider.userName ?? 'You';
    _ageNotifier.value = widget.provider.userAge ?? '—';
    _locationNotifier.value = widget.provider.userLocation ?? '—';
  }

  @override
  void dispose() {
    _nameNotifier.dispose();
    _ageNotifier.dispose();
    _locationNotifier.dispose();
    _emailNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showFocusSettings) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Mango header: avatar + name + level
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: EllaColors.mangoLight,
              boxShadow: [
                BoxShadow(
                  color: EllaColors.mangoDark,
                  offset: Offset(0, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: EllaColors.neutralSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Back to home screen',
                              style: GoogleFonts.baloo2(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: EllaColors.neutralSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: EllaColors.mangoLightest,
                        border: Border.all(color: EllaColors.mangoDark, width: 2),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 32,
                        color: EllaColors.mangoDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<String>(
                      valueListenable: _nameNotifier,
                      builder: (_, name, _) => Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Chillax',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: EllaColors.neutralPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your level · ${_friendlyLevelLabel(widget.provider.userLevel)}',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: EllaColors.mangoDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Gradient strip masks scroll bleed past the header shadow
          IgnorePointer(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    EllaColors.mangoLight,
                    EllaColors.mangoLight.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Info card section
          Expanded(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth:
                        EllaResponsive.isWide(context) ? 600 : double.infinity,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      EllaResponsive.isWide(context) ? 32 : 24,
                      20,
                      48,
                    ),
                    child: _YourInfoSection(provider: widget.provider),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Wide (web/tablet): full-width mango header + centered 540px content column
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: EllaColors.mangoLight,
            boxShadow: [
              BoxShadow(
                color: EllaColors.mangoDark,
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: EllaColors.neutralSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Back to home screen',
                            style: GoogleFonts.baloo2(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: EllaColors.neutralSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: EllaColors.mangoLightest,
                      border: Border.all(color: EllaColors.mangoDark, width: 2),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: EllaColors.mangoDark,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<String>(
                    valueListenable: _nameNotifier,
                    builder: (_, name, _) => Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Chillax',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: EllaColors.neutralPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You speak · ${_friendlyLevelLabel(widget.provider.userLevel)}',
                    style: GoogleFonts.baloo2(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.mangoDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Gradient strip masks scroll bleed past the header shadow
        IgnorePointer(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  EllaColors.mangoLight,
                  EllaColors.mangoLight.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _YourInfoSection(provider: widget.provider),
                      const SizedBox(height: 32),
                      const _CoachingStyleSection(horizontalPadding: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Your Info Section ────────────────────────────────────────────────────────

class _YourInfoSection extends StatefulWidget {
  final ChatProvider provider;
  const _YourInfoSection({required this.provider});

  @override
  State<_YourInfoSection> createState() => _YourInfoSectionState();
}

class _YourInfoSectionState extends State<_YourInfoSection> {
  late final ValueNotifier<String> _nameNotifier;
  late final ValueNotifier<String> _ageNotifier;
  late final ValueNotifier<String> _locationNotifier;
  late final ValueNotifier<String> _emailNotifier;

  @override
  void initState() {
    super.initState();
    _nameNotifier = ValueNotifier(widget.provider.userName ?? 'You');
    _ageNotifier = ValueNotifier(widget.provider.userAge ?? '—');
    _locationNotifier = ValueNotifier(widget.provider.userLocation ?? '—');
    _emailNotifier = ValueNotifier(_mockEmail);
  }

  @override
  void didUpdateWidget(_YourInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync notifiers if provider data changed externally
    _nameNotifier.value = widget.provider.userName ?? 'You';
    _ageNotifier.value = widget.provider.userAge ?? '—';
    _locationNotifier.value = widget.provider.userLocation ?? '—';
  }

  @override
  void dispose() {
    _nameNotifier.dispose();
    _ageNotifier.dispose();
    _locationNotifier.dispose();
    _emailNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _eyebrow('YOUR INFO'),
            const Spacer(),
            GestureDetector(
              onTap: () => _showEditSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: EllaColors.mangoLightest,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: EllaColors.mangoDark, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: EllaColors.mangoDark,
                      offset: Offset(0, 2),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.edit_rounded,
                      size: 13,
                      color: EllaColors.mangoDark,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Edit',
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: EllaColors.mangoDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: EllaColors.neutralBorder, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: EllaColors.neutralBorder,
                offset: Offset(0, 3),
                blurRadius: 0,
              ),
            ],
          ),
          child: Column(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: _nameNotifier,
                builder: (_, val, _) => _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'NAME',
                  value: val,
                  isLast: false,
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: _ageNotifier,
                builder: (_, val, _) => _InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'AGE',
                  value: val,
                  isLast: false,
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: _locationNotifier,
                builder: (_, val, _) => _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'LOCATION',
                  value: val,
                  isLast: false,
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: _emailNotifier,
                builder: (_, val, _) => _InfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'EMAIL',
                  value: val,
                  isLast: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: _nameNotifier.value);
    final ageCtrl = TextEditingController(text: _ageNotifier.value);
    final locationCtrl = TextEditingController(text: _locationNotifier.value);
    final emailCtrl = TextEditingController(text: _emailNotifier.value);

    void onSave(BuildContext dismissContext) {
      _nameNotifier.value = nameCtrl.text;
      _ageNotifier.value = ageCtrl.text;
      _locationNotifier.value = locationCtrl.text;
      _emailNotifier.value = emailCtrl.text;
      widget.provider.setUserProfile(
        name: nameCtrl.text,
        age: ageCtrl.text,
        location: locationCtrl.text,
      );
      Navigator.of(dismissContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile updated',
            style: GoogleFonts.baloo2(fontWeight: FontWeight.w600),
          ),
          backgroundColor: EllaColors.neutralPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    Widget formContent(BuildContext dismissContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Edit your info',
          style: TextStyle(
            fontFamily: 'Chillax',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: EllaColors.neutralPrimary,
          ),
        ),
        const SizedBox(height: 20),
        _EditField(label: 'Name', controller: nameCtrl),
        const SizedBox(height: 12),
        _EditField(label: 'Age', controller: ageCtrl),
        const SizedBox(height: 12),
        _EditField(label: 'Location', controller: locationCtrl),
        const SizedBox(height: 12),
        _EditField(label: 'Email', controller: emailCtrl),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => onSave(dismissContext),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: EllaColors.mangoMain,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(4),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: EllaColors.mangoDark,
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: Text(
                'Save profile info',
                style: GoogleFonts.baloo2(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: EllaColors.neutralPrimary,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    if (EllaResponsive.isWide(context)) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: formContent(dialogContext),
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: EllaColors.neutralBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: SingleChildScrollView(child: formContent(sheetContext)),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: EllaColors.neutralMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontFamily: 'Inconsolata',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: EllaColors.neutralMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.baloo2(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: EllaColors.neutralPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            thickness: 1,
            color: EllaColors.neutralBorder,
          ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _EditField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'Inconsolata',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: EllaColors.neutralMuted,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.baloo2(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: EllaColors.neutralPrimary,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: EllaColors.neutralBorder,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: EllaColors.neutralBorder,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: EllaColors.skyMain, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Zoe's Coaching Style Section ────────────────────────────────────────────

class _CoachingStyleSection extends StatelessWidget {
  final double horizontalPadding;
  const _CoachingStyleSection({this.horizontalPadding = 20});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final settings = provider.focusSettings;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _eyebrow('ZOE\'S COACHING STYLE'),
              const SizedBox(height: 4),
              Text(
                'Zoe uses these in every session',
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: EllaColors.neutralSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _FocusBlock<GrammarFocus>(
                icon: Icons.spellcheck_rounded,
                iconColor: EllaColors.skyMain,
                title: 'Grammar',
                subtitle: 'How Zoe handles your grammar errors',
                values: GrammarFocus.values,
                selected: settings.grammar,
                onChanged: (v) =>
                    provider.updateFocusSettings(settings.copyWith(grammar: v)),
              ),
              const SizedBox(height: 20),
              _FocusBlock<VocabFocus>(
                icon: Icons.auto_stories_rounded,
                iconColor: EllaColors.limeMain,
                title: 'Vocabulary',
                subtitle: 'How actively Zoe suggests new words',
                values: VocabFocus.values,
                selected: settings.vocabulary,
                onChanged: (v) => provider.updateFocusSettings(
                  settings.copyWith(vocabulary: v),
                ),
              ),
              const SizedBox(height: 20),
              _FocusBlock<FluencyFocus>(
                icon: Icons.speed_rounded,
                iconColor: EllaColors.mangoMain,
                title: 'Fluency',
                subtitle: 'How Zoe tracks your pace and fillers',
                values: FluencyFocus.values,
                selected: settings.fluency,
                onChanged: (v) =>
                    provider.updateFocusSettings(settings.copyWith(fluency: v)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Generic Focus Block (chips + description) ────────────────────────────────

class _FocusBlock<T extends Enum> extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;

  const _FocusBlock({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  String _descriptionFor(T value) {
    if (value is GrammarFocus) return value.description;
    if (value is VocabFocus) return value.description;
    if (value is FluencyFocus) return value.description;
    return '';
  }

  String _labelFor(T value) {
    if (value is GrammarFocus) return value.label;
    if (value is VocabFocus) return value.label;
    if (value is FluencyFocus) return value.label;
    return value.name;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.baloo2(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: EllaColors.neutralPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.baloo2(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: EllaColors.neutralMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: const EdgeInsets.only(left: 2, right: 8),
          child: Row(
            children: values.map((v) {
              final isSelected = v == selected;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? EllaColors.mangoLightest
                          : Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: isSelected
                            ? EllaColors.mangoDark
                            : EllaColors.neutralBorder,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected
                              ? EllaColors.mangoDark
                              : EllaColors.neutralBorder,
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Text(
                      _labelFor(v),
                      style: GoogleFonts.baloo2(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? EllaColors.mangoDeepest
                            : EllaColors.neutralSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _descriptionFor(selected),
          style: GoogleFonts.baloo2(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: EllaColors.neutralSecondary,
          ),
        ),
      ],
    );
  }
}


class _LogoutSheetContent extends StatelessWidget {
  final bool showDragHandle;
  final VoidCallback onStay;
  final Future<void> Function() onLogout;

  const _LogoutSheetContent({
    required this.showDragHandle,
    required this.onStay,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showDragHandle) ...[
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
        ] else
          const SizedBox(height: 4),
        const Text(
          'Logout of Zoe?',
          style: TextStyle(
            fontFamily: 'Chillax',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: EllaColors.neutralPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your saved profile and coaching style will be cleared from this device.',
          style: GoogleFonts.baloo2(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: EllaColors.neutralSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => onLogout(),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                child: Center(
                  child: Text(
                    'LOG OUT',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onStay,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [EllaColors.mangoTop, EllaColors.mangoMain],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                    bottomLeft: Radius.circular(20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: EllaColors.mangoDark,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'STAY',
                    style: GoogleFonts.baloo2(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


class _LogoutSheet extends StatelessWidget {
  final VoidCallback onStay;
  final Future<void> Function() onLogout;

  const _LogoutSheet({required this.onStay, required this.onLogout});

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
        child: _LogoutSheetContent(
          showDragHandle: true,
          onStay: onStay,
          onLogout: onLogout,
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Widget _eyebrow(String text) => Text(
  text,
  style: const TextStyle(
    fontFamily: 'Inconsolata',
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: EllaColors.neutralMuted,
    letterSpacing: 0.8,
  ),
);
