import 'package:flutter/material.dart';
import '../core/text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A2B)),
        title: Text('Privacy Policy', style: EllaTextStyles.titleMedium),
        centerTitle: true,
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
              'Welcome to ZoSpeak. We are committed to protecting your personal information and your right to privacy. If you have any questions or concerns about our policy, or our practices with regards to your personal information, please contact us.\n\n'
              'When you visit our mobile application, and use our services, you trust us with your personal information. We take your privacy very seriously. In this privacy policy, we seek to explain to you in the clearest way possible what information we collect, how we use it and what rights you have in relation to it.\n\n'
              'Please read this privacy policy carefully as it will help you make informed decisions about sharing your personal information with us.\n\n'
              '1. WHAT INFORMATION DO WE COLLECT?\n'
              'We collect personal information that you provide to us.\n\n'
              '2. HOW DO WE USE YOUR INFORMATION?\n'
              'We process your information for purposes based on legitimate business interests, the fulfillment of our contract with you, compliance with our legal obligations, and/or your consent.\n\n'
              '3. WILL YOUR INFORMATION BE SHARED WITH ANYONE?\n'
              'We only share information with your consent, to comply with laws, to provide you with services, to protect your rights, or to fulfill business obligations.',
              style: EllaTextStyles.bodyBase,
            ),
          ],
        ),
      ),
    );
  }
}
