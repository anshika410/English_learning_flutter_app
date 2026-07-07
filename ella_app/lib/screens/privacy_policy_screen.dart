import 'package:flutter/material.dart';
import '../core/theme_colors.dart';
import '../core/text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EllaColors.canvas,
      appBar: AppBar(
        title: Text('Privacy Policy', style: EllaTextStyles.titleMedium),
        backgroundColor: EllaColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: EllaColors.ink),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: EllaTextStyles.headline,
            ),
            const SizedBox(height: 16),
            Text(
              'Last updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
              style: EllaTextStyles.caption.copyWith(color: EllaColors.ink.withOpacity(0.6)),
            ),
            const SizedBox(height: 32),
            _buildSection(
              '1. Introduction',
              'Welcome to ELLA. We are committed to protecting your personal information and your right to privacy. If you have any questions or concerns about our policy, or our practices with regards to your personal information, please contact us.',
            ),
            _buildSection(
              '2. Information We Collect',
              'We collect personal information that you provide to us such as name, email address, contact information, passwords, and security data. We may also collect information automatically when you use our app, including device and usage information.',
            ),
            _buildSection(
              '3. How We Use Your Information',
              'We use personal information collected via our App for a variety of business purposes described below. We process your personal information for these purposes in reliance on our legitimate business interests, in order to enter into or perform a contract with you, with your consent, and/or for compliance with our legal obligations.',
            ),
            _buildSection(
              '4. Will Your Information be Shared with Anyone?',
              'We only share information with your consent, to comply with laws, to provide you with services, to protect your rights, or to fulfill business obligations.',
            ),
            _buildSection(
              '5. Contact Us',
              'If you have questions or comments about this policy, you may email us or contact us through the app support system.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: EllaTextStyles.titleSmall),
          const SizedBox(height: 8),
          Text(content, style: EllaTextStyles.bodyBase),
        ],
      ),
    );
  }
}
