import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/focus_settings.dart';
import '../providers/chat_provider.dart';
import '../theme/ella_responsive.dart';
import '../theme/ella_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    final level = provider.userLevel ?? 'A2';
    final showFocusSettings = !_isBelowB1(level);
    return Scaffold(
      backgroundColor: EllaColors.neutralBg,
      body: SingleChildScrollView(
        child: _ProfileHeader(
          provider: provider,
          showFocusSettings: showFocusSettings,
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatefulWidget {
  final ChatProvider provider;
  final bool showFocusSettings;
  const _ProfileHeader({required this.provider, required this.showFocusSettings});

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

  void _showEditSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: _nameNotifier.value);
    final ageCtrl = TextEditingController(text: _ageNotifier.value);
    final locationCtrl = TextEditingController(text: _locationNotifier.value);
    final emailCtrl = TextEditingController(text: _emailNotifier.value);

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(dialogContext).viewInsets.bottom,
                left: 16,
                right: 16,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: EllaColors.neutralBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
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
                          onTap: () {
                            _nameNotifier.value = nameCtrl.text;
                            _ageNotifier.value = ageCtrl.text;
                            _locationNotifier.value = locationCtrl.text;
                            _emailNotifier.value = emailCtrl.text;
                            widget.provider.setUserProfile(
                              name: nameCtrl.text,
                              age: ageCtrl.text,
                              location: locationCtrl.text,
                            );
                            Navigator.of(context).pop();
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
                          },
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
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar circle
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
            color: EllaColors.mangoMain,
          ),
        ),
        const SizedBox(height: 12),
        // Name
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
        // "You speak · level"
        Text(
          'You speak · ${_friendlyLevelLabel(widget.provider.userLevel)}',
          style: GoogleFonts.baloo2(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: EllaColors.neutralSecondary,
          ),
        ),
        const SizedBox(height: 8),
        // Location
        ValueListenableBuilder<String>(
          valueListenable: _locationNotifier,
          builder: (_, loc, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: EllaColors.neutralMuted),
              const SizedBox(width: 4),
              Text(
                loc,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: EllaColors.neutralSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Email
        ValueListenableBuilder<String>(
          valueListenable: _emailNotifier,
          builder: (_, email, _) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mail_outline_rounded, size: 14, color: EllaColors.neutralMuted),
              const SizedBox(width: 4),
              Text(
                email,
                style: GoogleFonts.baloo2(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: EllaColors.neutralSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Edit Profile button
        GestureDetector(
          onTap: () => _showEditSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                const Icon(Icons.edit_rounded, size: 13, color: EllaColors.mangoDark),
                const SizedBox(width: 4),
                Text(
                  'Edit Profile',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = EllaResponsive.isWide(context);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button — 24px from top
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 24),
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
          const SizedBox(height: 48),
          // Content: two-column on wide, stacked on narrow
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 768),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: isWide && widget.showFocusSettings
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileInfo(context),
                          const SizedBox(width: 48),
                          const Expanded(
                            child: _CoachingStyleSection(horizontalPadding: 0),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileInfo(context),
                          if (widget.showFocusSettings) ...[
                            const SizedBox(height: 32),
                            const _CoachingStyleSection(horizontalPadding: 0),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Your Info Section ────────────────────────────────────────────────────────

class _YourInfoSection extends StatefulWidget {
  final ChatProvider provider;
  final double horizontalPadding;
  const _YourInfoSection({required this.provider, this.horizontalPadding = 20});

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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.horizontalPadding),
      child: Column(
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
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: _nameNotifier.value);
    final ageCtrl = TextEditingController(text: _ageNotifier.value);
    final locationCtrl = TextEditingController(text: _locationNotifier.value);
    final emailCtrl = TextEditingController(text: _emailNotifier.value);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: SingleChildScrollView(
          child: Container(
            decoration: BoxDecoration(
              color: EllaColors.neutralBg,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
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
                    onTap: () {
                      _nameNotifier.value = nameCtrl.text;
                      _ageNotifier.value = ageCtrl.text;
                      _locationNotifier.value = locationCtrl.text;
                      _emailNotifier.value = emailCtrl.text;
                      widget.provider.setUserProfile(
                        name: nameCtrl.text,
                        age: ageCtrl.text,
                        location: locationCtrl.text,
                      );
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Profile updated',
                            style: GoogleFonts.baloo2(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: EllaColors.neutralPrimary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
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
            ),
          ),
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
