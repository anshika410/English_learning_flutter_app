import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/theme_colors.dart';
import '../../../core/text_styles.dart';
import '../../../providers/onboarding_provider.dart';

class EditProfileDialog extends ConsumerStatefulWidget {
  final String initialName;
  final int initialAge;

  const EditProfileDialog({
    super.key,
    required this.initialName,
    required this.initialAge,
  });

  static Future<bool?> show(
      BuildContext context, String name, int age) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Edit Profile',
      barrierColor: Colors.black.withValues(alpha: 0.4),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: EditProfileDialog(
                initialName: name,
                initialAge: age,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<EditProfileDialog> {
  static const _asset = 'assets/profile';

  late TextEditingController _nameController;
  late TextEditingController _ageController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _ageController = TextEditingController(text: widget.initialAge.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    final age = int.tryParse(ageText);

    if (name.isEmpty || age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and age.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(onboardingProvider.notifier).updateProfile(name: name, age: age);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Profile update failed: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Couldn't save changes"),
            content: const Text('Try again'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Amulya Bold 20 — labels + banner title.
  TextStyle get _title => EllaFonts.bricolage(const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.6,
        letterSpacing: 0.4,
        color: EllaColors.onPrimary,
      ));

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width - 40;
    final width = maxWidth < 387.0 ? maxWidth : 387.0;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _woodBanner('Edit Profile'),
          const SizedBox(height: 16),
          _label('Name'),
          const SizedBox(height: 8),
          _field(controller: _nameController),
          const SizedBox(height: 16),
          _label('Age'),
          const SizedBox(height: 8),
          _field(
            controller: _ageController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _updateButton(),
        ],
      ),
    );
  }

  Widget _woodBanner(String text) {
    const dot = SizedBox(
      width: 6,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFF5A3110),
          shape: BoxShape.circle,
        ),
      ),
    );
    return Center(
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFC49050),
              Color(0xFF9B6828),
              Color(0xFFB08040),
              Color(0xFF966828),
              Color(0xFF8A5712),
            ],
            stops: [0.0, 0.28, 0.55, 0.78, 1.0],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              offset: Offset(0, 4),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: _title.copyWith(
                  shadows: const [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            dot,
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: _title);

  Widget _field({
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: EllaColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: EllaColors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: const InputDecoration(
          border: InputBorder.none,
          isCollapsed: true,
        ),
        style: EllaFonts.body(const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.6,
          color: EllaColors.ink,
        )),
      ),
    );
  }

  Widget _updateButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _updateProfile,
      child: Container(
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: EllaColors.berryMain,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: EllaColors.berryDeep, width: 3),
          boxShadow: const [
            BoxShadow(
              color: EllaColors.berryDeep,
              offset: Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset('$_asset/checks.svg', width: 32, height: 32),
            const SizedBox(width: 12),
            Text(
              'Save Changes',
              style: EllaFonts.body(const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.6,
                color: EllaColors.onPrimary,
              )),
            ),
          ],
        ),
      ),
    );
  }
}
