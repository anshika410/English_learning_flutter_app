import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/text_styles.dart';

class PrivacyPolicyWebviewScreen extends StatefulWidget {
  final String url;

  const PrivacyPolicyWebviewScreen({
    super.key,
    this.url = 'https://ella.navgurukul.org/privacypolicy/',
  });

  @override
  State<PrivacyPolicyWebviewScreen> createState() => _PrivacyPolicyWebviewScreenState();
}

class _PrivacyPolicyWebviewScreenState extends State<PrivacyPolicyWebviewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Privacy Policy', style: EllaTextStyles.titleMedium),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E3A2B)),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E3A2B)),
              ),
            ),
        ],
      ),
    );
  }
}
