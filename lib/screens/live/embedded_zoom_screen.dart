import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
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

  // Landscape controls state
  bool _controlsVisible = true;
  Timer? _hideTimer;
  Offset? _pipPosition;
  bool _isMuted = false;
  bool _isVideoOff = false;

  static const double _pipWidth = 130.0;
  static const double _pipHeight = 85.0;

  @override
  void initState() {
    super.initState();

    // Enable all orientations so user can smoothly rotate between portrait & landscape
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      _requestPermissionsAndInitWebView();
    } else {
      _isLoading = false;
      final classroomUrl =
          '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';
      _launchClassroomUrl(classroomUrl);
    }

    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _resetInactivityTimer() {
    if (_controlsVisible) {
      _startHideTimer();
    }
  }

  Future<void> _requestPermissionsAndInitWebView() async {
    // Trigger OS Native Permission Prompt for Camera & Mic
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
    // Desktop user agents bypass Zoom's mobile block.
    // iOS WebKit requires Safari's user agent to activate its WebKit-compatible WebRTC pipeline.
    final String userAgent = defaultTargetPlatform == TargetPlatform.iOS
        ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36";

    final classroomUrl =
        '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';

    // Configure platform-specific parameters (critical for iOS WebRTC camera/audio)
    late final PlatformWebViewControllerCreationParams params;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (WebViewPermissionRequest request) {
        request.grant();
      },
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(userAgent)
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
          request.grant();
        },
      );
    }

    // Enable iOS WebKit permission auto-grant for WebRTC camera and mic
    if (controller.platform is WebKitWebViewController) {
      final webKitController = controller.platform as WebKitWebViewController;
      webKitController.setOnPlatformPermissionRequest(
        (PlatformWebViewPermissionRequest request) {
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
        // 1. Zoom SDK Overlay, Share Screen & AI Companion Suppression CSS Fixes
        var styleId = 'zoom-overlay-fix-style';
        var existingStyle = document.getElementById(styleId);
        if (!existingStyle) {
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
            /* Strict Exclusion 1: Hide Zoom Screen Share Buttons */
            button[aria-label*="Share Screen"],
            button[aria-label*="share screen"],
            button[aria-label*="Share"],
            button[aria-label*="share"],
            button[class*="share-btn"],
            div[class*="share-btn"],
            .footer-button__share-screen,
            .footer-button-base__share,
            #wc-footer .share-button,
            [class*="share-screen"],
            [class*="share-button"],
            [aria-label="Share Screen"],
            [aria-label="Share screen"],
            [aria-label="share screen"] {
              display: none !important;
              visibility: hidden !important;
              pointer-events: none !important;
              opacity: 0 !important;
              width: 0 !important;
              height: 0 !important;
              margin: 0 !important;
              padding: 0 !important;
            }
            /* Strict Exclusion 2: Hide Zoom AI Companion Buttons */
            button[aria-label*="AI Companion"],
            button[aria-label*="ai companion"],
            button[aria-label*="AI"],
            button[aria-label*="ai"],
            button[aria-label*="Companion"],
            button[aria-label*="companion"],
            button[class*="ai-companion"],
            div[class*="ai-companion"],
            .footer-button__ai-companion,
            [class*="ai-companion"],
            [class*="companion-btn"],
            [class*="ai-summary"],
            [class*="ai-assistant"],
            #wc-footer [class*="companion"],
            #wc-footer [class*="ai"] {
              display: none !important;
              visibility: hidden !important;
              pointer-events: none !important;
              opacity: 0 !important;
              width: 0 !important;
              height: 0 !important;
              margin: 0 !important;
              padding: 0 !important;
            }
          `;
          (document.head || document.documentElement).appendChild(style);
        }

        // 2. Active DOM Mutation Observer to continuously remove Share and AI Companion buttons
        function removeUnwantedButtons() {
          var unwantedSelectors = [
            'button[aria-label*="Share"]',
            'button[aria-label*="share"]',
            '.footer-button__share-screen',
            '[class*="share-screen"]',
            '[class*="share-btn"]',
            'button[aria-label*="AI"]',
            'button[aria-label*="ai"]',
            'button[aria-label*="Companion"]',
            'button[aria-label*="companion"]',
            '[class*="ai-companion"]',
            '[class*="companion"]'
          ];
          var btns = document.querySelectorAll(unwantedSelectors.join(','));
          btns.forEach(function(btn) {
            btn.style.display = 'none';
            btn.style.visibility = 'hidden';
            btn.style.pointerEvents = 'none';
          });
        }
        removeUnwantedButtons();
        setInterval(removeUnwantedButtons, 1000);
      })();
    ''';
    _controller!.runJavaScript(js).catchError((e) {
      debugPrint("Error injecting Zoom overlay fix JS: $e");
    });
  }

  void _toggleAudio() {
    _resetInactivityTimer();
    setState(() {
      _isMuted = !_isMuted;
    });
    // Trigger Zoom Web SDK mute button click in DOM if available
    _controller?.runJavaScript('''
      (function() {
        var micBtn = document.querySelector('button[aria-label*="Mute"], button[aria-label*="mute"], button[aria-label*="Audio"], button[aria-label*="audio"]');
        if (micBtn) micBtn.click();
      })();
    ''');
  }

  void _toggleVideo() {
    _resetInactivityTimer();
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    // Trigger Zoom Web SDK video button click in DOM if available
    _controller?.runJavaScript('''
      (function() {
        var camBtn = document.querySelector('button[aria-label*="Video"], button[aria-label*="video"], button[aria-label*="camera"], button[aria-label*="Camera"]');
        if (camBtn) camBtn.click();
      })();
    ''');
  }

  void _handleLeaveClass(BuildContext context) {
    _resetInactivityTimer();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Classroom',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          'Are you sure you want to leave this live lecture?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
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
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          return _buildLandscapeUI();
        } else {
          return _buildPortraitUI();
        }
      },
    );
  }

  // ─── Portrait UI (Intact & Standard) ───────────────────────────────────────
  Widget _buildPortraitUI() {
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
        child: _buildVideoView(),
      ),
    );
  }

  // ─── Landscape UI (Immersive Video Conferencing Experience) ───────────────
  Widget _buildLandscapeUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 1. Fullscreen Hero: Main video feed taking full screen
              Positioned.fill(
                child: GestureDetector(
                  key: const Key('video_gesture_detector'),
                  behavior: HitTestBehavior.translucent,
                  onTap: _toggleControls,
                  child: Container(
                    color: Colors.black,
                    child: _buildVideoView(),
                  ),
                ),
              ),

              // 2. Auto-Hiding Overlay Controls (Top App Bar & Bottom Control Bar)
              IgnorePointer(
                ignoring: !_controlsVisible,
                child: AnimatedOpacity(
                  opacity: _controlsVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Stack(
                    children: [
                      // Top Bar Overlay
                      _buildTopOverlay(),

                      // Bottom Toolbar Overlay (Strictly without Share Screen or AI Companion)
                      _buildBottomOverlay(),
                    ],
                  ),
                ),
              ),

              // 3. Floating Draggable Self-View (Picture-in-Picture) - on top so user can freely drag anywhere
              _buildFloatingSelfView(constraints),
            ],
          );
        },
      ),
    );
  }

  // ─── Video View Helper ───────────────────────────────────────────────────
  Widget _buildVideoView() {
    if (kIsWeb) {
      return _buildWebPlaceholder();
    }
    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      );
    }
    return WebViewWidget(controller: _controller!);
  }

  // ─── Top Overlay Bar ─────────────────────────────────────────────────────
  Widget _buildTopOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black87,
              Colors.black45,
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Back Button
              InkWell(
                onTap: () => _handleLeaveClass(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),

              // LIVE Indicator Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.fiber_manual_record, color: Colors.white, size: 8),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Meeting / Course Title
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom Overlay Toolbar ──────────────────────────────────────────────
  Widget _buildBottomOverlay() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black87,
              Colors.black45,
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 8),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Mute / Unmute Audio
              _buildControlButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? 'Unmute' : 'Mute',
                isActive: !_isMuted,
                isDestructive: _isMuted,
                onTap: _toggleAudio,
              ),
              const SizedBox(width: 24),

              // 2. Start / Stop Video
              _buildControlButton(
                icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                label: _isVideoOff ? 'Start Video' : 'Stop Video',
                isActive: !_isVideoOff,
                isDestructive: _isVideoOff,
                onTap: _toggleVideo,
              ),
              const SizedBox(width: 24),

              // 3. Leave Class
              _buildControlButton(
                icon: Icons.call_end,
                label: 'Leave',
                isActive: false,
                isDestructive: true,
                onTap: () => _handleLeaveClass(context),
              ),

              // STRICT REQUIREMENT:
              // No "Share Screen" button.
              // No "Zoom AI Companion" button.
              // (Both are excluded from the custom bottom toolbar)
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDestructive,
    required VoidCallback onTap,
  }) {
    Color buttonBg;
    if (isDestructive) {
      buttonBg = Colors.red.withValues(alpha: 0.85);
    } else if (isActive) {
      buttonBg = Colors.white.withValues(alpha: 0.18);
    } else {
      buttonBg = Colors.white.withValues(alpha: 0.1);
    }

    return InkWell(
      onTap: () {
        _resetInactivityTimer();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: buttonBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDestructive ? Colors.redAccent : Colors.white24,
                  width: 1,
                ),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Floating Draggable Self-View Box ─────────────────────────────────────
  Widget _buildFloatingSelfView(BoxConstraints constraints) {
    // Default initial position: Bottom right corner
    final double defaultX = constraints.maxWidth - _pipWidth - 16;
    final double defaultY = constraints.maxHeight - _pipHeight - 75;

    final Offset currentPos = _pipPosition ??
        Offset(defaultX > 0 ? defaultX : 16, defaultY > 0 ? defaultY : 16);

    return Positioned(
      left: currentPos.dx,
      top: currentPos.dy,
      child: GestureDetector(
        key: const Key('self_view_pip'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          _resetInactivityTimer();
          setState(() {
            final double newX = (currentPos.dx + details.delta.dx)
                .clamp(8.0, (constraints.maxWidth - _pipWidth - 8.0).clamp(8.0, double.infinity));
            final double newY = (currentPos.dy + details.delta.dy)
                .clamp(8.0, (constraints.maxHeight - _pipHeight - 8.0).clamp(8.0, double.infinity));
            _pipPosition = Offset(newX, newY);
          });
        },
        child: Container(
          width: _pipWidth,
          height: _pipHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: Stack(
              children: [
                // Camera status / preview content
                Center(
                  child: _isVideoOff
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.videocam_off, color: Colors.white54, size: 24),
                            SizedBox(height: 2),
                            Text(
                              'Camera Off',
                              style: TextStyle(color: Colors.white38, fontSize: 9),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppColors.primaryGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Self View',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),

                // Subtle top drag handle
                Positioned(
                  top: 4,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),

                // Bottom badge: "You" and mic indicator
                Positioned(
                  bottom: 4,
                  left: 6,
                  right: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'You',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _isMuted
                              ? Colors.red.withValues(alpha: 0.8)
                              : AppColors.primaryGreen.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                          size: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Web Placeholder ─────────────────────────────────────────────────────
  Widget _buildWebPlaceholder() {
    final classroomUrl =
        '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';
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
