import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';

class EmbeddedZoomScreen extends StatefulWidget {
  final String classId;
  final String token;
  final String title;

  const EmbeddedZoomScreen({
    super.key,
    required this.classId,
    required this.token,
    required this.title,
  });

  @override
  State<EmbeddedZoomScreen> createState() => _EmbeddedZoomScreenState();
}

class _EmbeddedZoomScreenState extends State<EmbeddedZoomScreen> {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Force landscape mode for Zoom Meeting screen
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }

    // Construct url with auth token query param
    final classroomUrl = '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';
    if (!kIsWeb) {
      // Initialize standard WebViewController
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.black)
        ..setUserAgent("PremierLMSMobileWebView")
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint("WebView error: ${error.description}");
            },
          ),
        );

      _controller!.loadRequest(Uri.parse(classroomUrl));
    } else {
      _isLoading = false;
      // On web, launch the class in a new tab immediately
      _launchClassroomUrl(classroomUrl);
    }
  }

  Future<void> _launchClassroomUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch $url");
    }
  }

  @override
  void dispose() {
    // Restore portrait mode on exit
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: kIsWeb
            ? _buildWebPlaceholder()
            : WebViewWidget(controller: _controller!),
      ),
    );
  }

  Widget _buildWebPlaceholder() {
    final classroomUrl = '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.open_in_new,
              color: AppColors.primaryGreen,
              size: 64,
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your virtual classroom is opening in a new tab.',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _launchClassroomUrl(classroomUrl),
              icon: const Icon(Icons.videocam),
              label: const Text('Join Class Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
