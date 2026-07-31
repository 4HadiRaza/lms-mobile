import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:flutter/services.dart';

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
      _requestPermissionsAndInitWebView();
    } else {
      _isLoading = false;
      final classroomUrl = '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';
      _launchClassroomUrl(classroomUrl);
    }
  }

  Future<void> _requestPermissionsAndInitWebView() async {
    // 1. Trigger OS Native Permission Prompt for Camera & Mic
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted) {
      _initWebView();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera and Microphone permissions are required for live classes.'),
          ),
        );
      }
      _initWebView();
    }
  }

  void _initWebView() {
    final String desktopUserAgent =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

    final classroomUrl =
        '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';

    // Initialize standard WebViewController with hardware permission handlers
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _injectZoomOverlayFix();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(classroomUrl));

    // Enable Android-specific WebRTC settings & disable user gesture requirement for media playback
    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      AndroidWebViewController.enableDebugging(false);
      androidController.setMediaPlaybackRequiresUserGesture(false);
      androidController.setOnPlatformPermissionRequest(
        (PlatformWebViewPermissionRequest request) {
          // Automatically grant WebRTC camera/mic access when requested by Zoom Web SDK
          request.grant();
        },
      );
    }

    if (mounted) {
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
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

  void _injectZoomOverlayFix() {
    if (_controller == null) return;
    const js = '''
      (function() {
        // 1. Zoom SDK Overlay CSS Fixes
        var styleId = 'zoom-overlay-fix-style';
        if (!document.getElementById(styleId)) {
          var style = document.createElement('style');
          style.id = styleId;
          style.type = 'text/css';
          style.innerHTML = `
            .aria-aria-modal-component,
            div[class*="join-audio"],
            div[class*="media-by-hardware-notice"],
            .theme-dark .join-audio-container {
              display: none !important;
              visibility: hidden !important;
              pointer-events: none !important;
            }
            .footer, .footer-bar, #wc-footer {
              z-index: 999999 !important;
              position: fixed !important;
              bottom: 0 !important;
              pointer-events: auto !important;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        }

        // 2. Polyfill getDisplayMedia so the Share Screen button renders
        if (navigator.mediaDevices && typeof navigator.mediaDevices.getDisplayMedia !== 'function') {
          navigator.mediaDevices.getDisplayMedia = function() {
            alert("Screen sharing is not supported in the mobile app. Please use a desktop browser to share your screen.");
            return Promise.reject(new Error("Screen sharing not supported in WebView."));
          };
        }
      })();
    ''';
    _controller!.runJavaScript(js).catchError((e) {
      debugPrint("Error injecting Zoom overlay fix JS: $e");
    });
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
            : (_controller == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : WebViewWidget(controller: _controller!)),
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
