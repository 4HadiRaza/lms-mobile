import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSpeakerOn = true;
  bool _isHandRaised = false;
  bool _isPreJoin = false;

  // Chat state
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();
  final ValueNotifier<int> _chatUpdateNotifier = ValueNotifier<int>(0);
  StateSetter? _chatModalSetState;


  @override
  void initState() {
    super.initState();

    // Support both landscape and portrait while guaranteeing 100% edge-to-edge full-screen video
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
      _requestPermissionsAndInitWebView();
    } else {
      _isLoading = false;
      final classroomUrl =
          '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';
      _launchClassroomUrl(classroomUrl);
    }

    // Controls initialize as visible (opacity: 1.0), then auto-fade out after 4 seconds of inactivity
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
      await _initWebView();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera and Microphone permissions are required for live classes.'),
          ),
        );
      }
      await _initWebView();
    }
  }

  Future<void> _initWebView() async {
    // Desktop user agents bypass Zoom's mobile block.
    // iOS WebKit requires Safari's user agent to activate its WebKit-compatible WebRTC pipeline.
    // 'PremierLMSMobileWebView' is required so the web app knows this is the official mobile app.
    final String userAgent = defaultTargetPlatform == TargetPlatform.iOS
        ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15 PremierLMSMobileWebView"
        : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 PremierLMSMobileWebView";

    final classroomUrl =
        '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';

    // Pre-seed cookies in the WebView so any immediate HTTP / API calls have the auth token
    try {
      final cookieManager = WebViewCookieManager();
      final uri = Uri.parse(classroomUrl);
      await cookieManager.setCookie(
        WebViewCookie(
          name: 'accessToken',
          value: widget.token,
          domain: uri.host,
          path: '/',
        ),
      );
      final cleanHost = uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;
      if (cleanHost != uri.host) {
        await cookieManager.setCookie(
          WebViewCookie(
            name: 'accessToken',
            value: widget.token,
            domain: cleanHost,
            path: '/',
          ),
        );
      }
    } catch (e) {
      debugPrint("Error pre-setting WebView cookies: $e");
    }

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

    late final WebViewController controller;
    controller = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (WebViewPermissionRequest request) {
        request.grant();
      },
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(userAgent)
      // ─── JS-to-Flutter Bridge Channel ───────────────────────────────
      // Receives JSON messages from injected JS to sync Zoom SDK state
      // back to Flutter (audio state, video state, chat messages, etc.)
      ..addJavaScriptChannel(
        'FlutterZoomBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleBridgeMessage(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            // If user left class or class ended, the web page redirects to /dashboard.
            // Pop back to native Flutter app instead of displaying the web dashboard.
            if (url.endsWith('/dashboard') ||
                (url.contains('/dashboard/classes') && !url.contains(widget.classId))) {
              debugPrint("Class ended or user left. Returning to app: $url");
              if (mounted) {
                Navigator.of(context).pop();
              }
              return NavigationDecision.prevent;
            }
            // Prevent redirecting the embedded WebView to the web login page
            if (url.contains('/auth/login') || url.contains('/login')) {
              debugPrint("Prevented WebView redirect to login: $url");
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
            // Inject session storage and cookie directly into DOM
            controller.runJavaScript('''
              try {
                localStorage.setItem('fromApp', 'true');
                document.cookie = "accessToken=${widget.token}; path=/; max-age=2592000; SameSite=Lax";
              } catch(e) {}
            ''').catchError((_) {});
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            _injectZoomOverlayFix(controller);
            _injectZoomBridgeScript(controller);
            // Re-apply fix at multiple intervals to survive dynamic imports, page replaces, and canvas creation
            for (final s in [1, 2, 4, 6, 8, 12, 16, 20, 25, 30]) {
              Future.delayed(Duration(seconds: s), () {
                if (mounted) {
                  _injectZoomOverlayFix(controller);
                  _injectZoomBridgeScript(controller);
                }
              });
            }
            // Re-affirm session tokens in DOM
            controller.runJavaScript('''
              try {
                localStorage.setItem('fromApp', 'true');
                document.cookie = "accessToken=${widget.token}; path=/; max-age=2592000; SameSite=Lax";
              } catch(e) {}
            ''').catchError((_) {});
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

  void _injectZoomOverlayFix([WebViewController? ctrl]) {
    final c = ctrl ?? _controller;
    if (c == null) return;
    const js = '''
      (function() {
        try {
          // 1. Zoom SDK Overlay, Share Screen & Layout CSS Fixes
          var styleId = 'zoom-overlay-fix-style';
          var existingStyle = document.getElementById(styleId);
          if (!existingStyle) {
            existingStyle = document.createElement('style');
            existingStyle.id = styleId;
            existingStyle.type = 'text/css';
            (document.head || document.documentElement).appendChild(existingStyle);
          }
          existingStyle.innerHTML = `
            /* 1. Global Viewport Reset: allow vertical touch scrolling */
            html, body {
              width: 100vw !important;
              min-height: 100vh !important;
              margin: 0 !important;
              padding: 0 !important;
              background-color: #000000 !important;
              overflow-x: hidden !important;
              overflow-y: auto !important;
              -webkit-overflow-scrolling: touch !important;
            }

            /* 2. Suppress Zoom SDK Native Overlays & Chrome */
            .aria-aria-modal-component,
            div[class*="join-audio"],
            div[class*="media-by-hardware-notice"],
            .theme-dark .join-audio-container,
            .footer, .footer-bar, #wc-footer,
            .meeting-info-container, .meeting-info-icon,
            [class*="meeting-header"], .participants-header, #wc-header,
            button[aria-label*="Share"], button[aria-label*="share"],
            .footer-button__share-screen, [class*="share-screen"], [class*="share-button"],
            button[aria-label*="AI"], button[aria-label*="Companion"], [class*="ai-companion"] {
              display: none !important;
              visibility: hidden !important;
              pointer-events: none !important;
              opacity: 0 !important;
              height: 0 !important;
              width: 0 !important;
            }

            /* 3. Zoom Container Hierarchy: Fill screen without clipping scrollable pre-join content */
            #zmmtg-root {
              width: 100vw !important;
              min-height: 100vh !important;
              margin: 0 !important;
              padding: 0 !important;
              background-color: #000000 !important;
              overflow-x: hidden !important;
              overflow-y: auto !important;
              -webkit-overflow-scrolling: touch !important;
              position: relative !important;
              box-sizing: border-box !important;
            }

            .meeting-client,
            .meeting-client-inner,
            #wc-content,
            #wc-container-left,
            .main-content,
            .meeting-app,
            #active-speaker-view,
            #active-video-container,
            .active-main,
            .speaker-view-container,
            .speaker-active-video {
              box-sizing: border-box !important;
            }

            /* 4. Active Video Canvas/Video in Meeting: FILL FULL SCREEN (NO LETTERBOXING) */
            #active-speaker-view canvas,
            #active-speaker-view video,
            #active-video-container canvas,
            #active-video-container video,
            .speaker-active-video canvas,
            .speaker-active-video video,
            .active-main canvas,
            .active-main video,
            .speaker-view-container canvas,
            .speaker-view-container video,
            #wc-content > div canvas:not([style*="pointer-events: none"]),
            #wc-content > div video {
              position: fixed !important;
              top: 0 !important;
              left: 0 !important;
              width: 100vw !important;
              height: 100vh !important;
              min-width: 100vw !important;
              min-height: 100vh !important;
              max-width: none !important;
              max-height: none !important;
              margin: 0 !important;
              padding: 0 !important;
              object-fit: cover !important;
              border: none !important;
              transform: none !important;
              z-index: 1 !important;
            }

            /* 5. Hide Zoom SDK Duplicate Participant Tiles & Speaker Bar (NO DUPLICATE VIEWS) */
            .speaker-bar-container,
            .speaker-bar,
            #speaker-bar,
            [class*="speaker-bar"],
            [class*="filmstrip"],
            [class*="gallery-video"],
            [class*="speaker-view-video"],
            .speaker-bar-item,
            .speaker-bar__video-item,
            .speaker-bar__video-list-container,
            .speaker-bar__video-list,
            .speaker-bar__video-wrap,
            .gallery-video-container,
            .gallery-video-item,
            .filmstrip-item {
              display: none !important;
              visibility: hidden !important;
              width: 0 !important;
              height: 0 !important;
              pointer-events: none !important;
              opacity: 0 !important;
              position: fixed !important;
              bottom: -9999px !important;
              left: -9999px !important;
            }

            /* 6. ONE CAMERA VIEW: Zoom SDK Native Self-View in Bottom-Right Corner */
            #self-video-container,
            .self-video-container,
            div[class*="self-video"],
            div[class*="self-view"] {
              position: fixed !important;
              bottom: 75px !important;
              right: 16px !important;
              top: auto !important;
              left: auto !important;
              transform: none !important;
              width: 130px !important;
              height: 85px !important;
              max-width: 130px !important;
              max-height: 85px !important;
              min-width: 130px !important;
              min-height: 85px !important;
              z-index: 9999 !important;
              border-radius: 12px !important;
              overflow: hidden !important;
              box-shadow: 0 4px 16px rgba(0, 0, 0, 0.7) !important;
              border: 1.5px solid rgba(255, 255, 255, 0.35) !important;
              background: #0f172a !important;
              touch-action: none !important;
            }

            /* Self-view canvas and video elements inside the PIP container */
            #self-video-container canvas,
            #self-video-container video,
            .self-video-container canvas,
            .self-video-container video,
            div[class*="self-video"] canvas,
            div[class*="self-video"] video,
            div[class*="self-view"] canvas,
            div[class*="self-view"] video {
              position: static !important;
              top: auto !important;
              left: auto !important;
              transform: none !important;
              width: 100% !important;
              height: 100% !important;
              min-width: 100% !important;
              min-height: 100% !important;
              max-width: 100% !important;
              max-height: 100% !important;
              object-fit: cover !important;
              border-radius: 10px !important;
              z-index: auto !important;
            }

            /* 7. Pre-Join Preview Screen Styling & Full Touch Scrollability */
            .preview-meeting,
            .preview-video,
            [class*="preview-meeting"],
            [class*="preview-video"],
            [class*="preview-content"],
            [class*="preview-dialog"],
            [class*="join-dialog"],
            [class*="meeting-preview"],
            div[class*="preview"] {
              overflow-y: auto !important;
              -webkit-overflow-scrolling: touch !important;
              box-sizing: border-box !important;
            }

            /* Landscape Responsive Tuning for Pre-Join Screen */
            @media (max-height: 520px) {
              .preview-meeting,
              [class*="preview-meeting"],
              [class*="preview-dialog"],
              [class*="join-dialog"],
              [class*="meeting-preview"] {
                padding-top: 4px !important;
                padding-bottom: 70px !important;
              }

              div[class*="preview-video"] > div,
              [class*="preview-video-container"],
              [class*="preview-avatar"],
              [class*="preview-video"] {
                max-height: 130px !important;
                margin-top: 4px !important;
                margin-bottom: 4px !important;
              }

              button.preview-join-button,
              button[class*="preview-join"],
              button[class*="join-btn"],
              .preview-join-button {
                margin-top: 8px !important;
                margin-bottom: 24px !important;
                min-height: 44px !important;
                font-size: 15px !important;
              }
            }
          `;

          // Layout Enforcer: Clean, non-destructive DOM stabilizer
          function enforceMeetingLayout() {
            try {
              // ── Check if Pre-Join Preview Screen is Active ──
              var joinBtn = document.querySelector(
                'button.preview-join-button, button[class*="preview-join"], button[class*="join-btn"], button[class*="btn-join"], .preview-join-button'
              );
              if (!joinBtn) {
                var allBtns = document.querySelectorAll('button, [role="button"]');
                for (var i = 0; i < allBtns.length; i++) {
                  var txt = (allBtns[i].innerText || allBtns[i].textContent || '').trim().toLowerCase();
                  if (txt === 'join' || txt === 'join meeting') {
                    joinBtn = allBtns[i];
                    break;
                  }
                }
              }

              if (joinBtn) {
                // WE ARE ON THE PRE-JOIN PREVIEW SCREEN!
                // Ensure all ancestors allow vertical touch scrolling
                document.documentElement.style.setProperty('overflow-y', 'auto', 'important');
                document.documentElement.style.setProperty('-webkit-overflow-scrolling', 'touch', 'important');
                document.body.style.setProperty('overflow-y', 'auto', 'important');
                document.body.style.setProperty('-webkit-overflow-scrolling', 'touch', 'important');
                document.body.style.setProperty('position', 'static', 'important');

                var zRoot = document.getElementById('zmmtg-root');
                if (zRoot) {
                  zRoot.style.setProperty('overflow-y', 'auto', 'important');
                  zRoot.style.setProperty('-webkit-overflow-scrolling', 'touch', 'important');
                  zRoot.style.setProperty('position', 'relative', 'important');
                  zRoot.style.setProperty('height', 'auto', 'important');
                  zRoot.style.setProperty('min-height', '100vh', 'important');
                }

                var curr = joinBtn.parentElement;
                while (curr && curr !== document.body) {
                  curr.style.setProperty('overflow-y', 'auto', 'important');
                  curr.style.setProperty('-webkit-overflow-scrolling', 'touch', 'important');
                  curr = curr.parentElement;
                }

                // Smoothly bring join button into visible area in landscape
                if (!window.__joinBtnScrolled) {
                  window.__joinBtnScrolled = true;
                  setTimeout(function() {
                    try {
                      joinBtn.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    } catch(e) {}
                  }, 400);
                }

                if (window.FlutterZoomBridge) {
                  window.__wasInPreJoin = true;
                  window.FlutterZoomBridge.postMessage(JSON.stringify({ type: 'preJoinState', inPreJoin: true }));
                }
                return;
              } else {
                if (window.FlutterZoomBridge && window.__wasInPreJoin) {
                  window.__wasInPreJoin = false;
                  window.FlutterZoomBridge.postMessage(JSON.stringify({ type: 'preJoinState', inPreJoin: false }));
                }
              }

              // ── IN-MEETING LAYOUT ENFORCEMENT ──
              var pipEl = document.querySelector('#self-video-container, .self-video-container, [class*="self-video"], [class*="self-view"]');
              if (pipEl) {
                if (!pipEl.__isDragging) {
                  pipEl.style.setProperty('position', 'fixed', 'important');
                  pipEl.style.setProperty('bottom', (pipEl.__customBottom || 75) + 'px', 'important');
                  pipEl.style.setProperty('right', (pipEl.__customRight || 16) + 'px', 'important');
                  pipEl.style.setProperty('top', 'auto', 'important');
                  pipEl.style.setProperty('left', 'auto', 'important');
                  pipEl.style.setProperty('transform', 'none', 'important');
                  pipEl.style.setProperty('width', '130px', 'important');
                  pipEl.style.setProperty('height', '85px', 'important');
                  pipEl.style.setProperty('z-index', '9999', 'important');
                }
                makePipDraggable(pipEl);
              }

              // Hide duplicate speaker bar / filmstrip / gallery tiles
              var dupes = document.querySelectorAll(
                '.speaker-bar, .speaker-bar-container, #speaker-bar, [class*="speaker-bar"], [class*="filmstrip"], [class*="gallery-video"], .speaker-bar-item, .filmstrip-item, .gallery-video-item'
              );
              dupes.forEach(function(d) {
                try {
                  if (pipEl && (pipEl === d || pipEl.contains(d))) return;
                  d.style.setProperty('display', 'none', 'important');
                  d.style.setProperty('visibility', 'hidden', 'important');
                  d.style.setProperty('position', 'fixed', 'important');
                  d.style.setProperty('bottom', '-9999px', 'important');
                  d.style.setProperty('pointer-events', 'none', 'important');
                } catch(e) {}
              });

              // Ensure active speaker video canvas fills 100% screen with NO letterboxing
              var activeVideos = document.querySelectorAll(
                '#active-speaker-view canvas, #active-speaker-view video, #active-video-container canvas, #active-video-container video, .speaker-active-video canvas, .speaker-active-video video, .active-main canvas, .active-main video, .speaker-view-container canvas, .speaker-view-container video'
              );
              activeVideos.forEach(function(av) {
                try {
                  av.style.setProperty('margin', '0px', 'important');
                  av.style.setProperty('margin-top', '0px', 'important');
                  av.style.setProperty('margin-left', '0px', 'important');
                  av.style.setProperty('padding', '0px', 'important');
                  av.style.setProperty('width', '100vw', 'important');
                  av.style.setProperty('height', '100vh', 'important');
                  av.style.setProperty('object-fit', 'cover', 'important');
                  av.style.setProperty('position', 'fixed', 'important');
                  av.style.setProperty('top', '0px', 'important');
                  av.style.setProperty('left', '0px', 'important');
                  av.style.setProperty('transform', 'none', 'important');
                } catch(e) {}
              });
            } catch(err) {}
          }

          function makePipDraggable(el) {
            try {
              if (el.__isPipDragInit) return;
              el.__isPipDragInit = true;
              var startX = 0, startY = 0;
              var initialRight = 16, initialBottom = 75;

              el.addEventListener('touchstart', function(e) {
                try {
                  if (e.touches.length !== 1) return;
                  el.__isDragging = true;
                  startX = e.touches[0].clientX;
                  startY = e.touches[0].clientY;
                  var rect = el.getBoundingClientRect();
                  initialRight = window.innerWidth - rect.right;
                  initialBottom = window.innerHeight - rect.bottom;
                } catch(e) {}
              }, { passive: true });

              el.addEventListener('touchmove', function(e) {
                try {
                  if (e.touches.length !== 1) return;
                  var deltaX = e.touches[0].clientX - startX;
                  var deltaY = e.touches[0].clientY - startY;
                  var newRight = Math.max(8, Math.min(window.innerWidth - 140, initialRight - deltaX));
                  var newBottom = Math.max(8, Math.min(window.innerHeight - 95, initialBottom - deltaY));
                  el.__customRight = newRight;
                  el.__customBottom = newBottom;
                  el.style.setProperty('right', newRight + 'px', 'important');
                  el.style.setProperty('bottom', newBottom + 'px', 'important');
                  el.style.setProperty('top', 'auto', 'important');
                  el.style.setProperty('left', 'auto', 'important');
                  el.style.setProperty('transform', 'none', 'important');
                } catch(e) {}
              }, { passive: true });

              el.addEventListener('touchend', function() {
                setTimeout(function() { el.__isDragging = false; }, 300);
              }, { passive: true });
            } catch(e) {}
          }

          enforceMeetingLayout();

          if (!window.__zoomLayoutInterval) {
            window.__zoomLayoutInterval = setInterval(enforceMeetingLayout, 250);
          }

          if (!window.__zoomLayoutObserver && window.MutationObserver) {
            try {
              var obs = new MutationObserver(function() {
                enforceMeetingLayout();
              });
              obs.observe(document.body || document.documentElement, { childList: true, subtree: true });
              window.__zoomLayoutObserver = obs;
            } catch(e) {}
          }
        } catch(topErr) {}
      })();
    ''';
    c.runJavaScript(js).catchError((e) {
      debugPrint("Error injecting Zoom overlay fix JS: $e");
    });
  }

  // ─── JS-to-Flutter Bridge Script Injection ──────────────────────────────────
  // Injects JS that listens to Zoom SDK in-meeting events AND performs
  // live DOM scraping on Zoom's chat messages, posting state changes back to Flutter.
  void _injectZoomBridgeScript([WebViewController? ctrl]) {
    final c = ctrl ?? _controller;
    if (c == null) return;
    const bridgeJs = '''
      (function() {
        if (window.__premierBridgeInjected) return;
        window.__premierBridgeInjected = true;

        window.__premierSentMessages = window.__premierSentMessages || new Set();
        var scrapedSignatures = new Set();

        function postToFlutter(data) {
          try {
            if (window.FlutterZoomBridge) {
              FlutterZoomBridge.postMessage(JSON.stringify(data));
            }
          } catch(e) { console.warn('Bridge post error:', e); }
        }

        // 1. Hook Zoom SDK JS events if ZoomMtg is available
        function hookZoomMtg() {
          var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
          if (!zm || window.__premierZoomMtgHooked) return;
          window.__premierZoomMtgHooked = true;

          try {
            zm.inMeetingServiceListener('onAudioStateChange', function(data) {
              if (data) postToFlutter({ type: 'audioState', muted: !!data.muted });
            });
          } catch(e) {}

          try {
            zm.inMeetingServiceListener('onVideoStateChange', function(data) {
              if (data) postToFlutter({ type: 'videoState', videoOff: !data.bVideoOn });
            });
          } catch(e) {}

          try {
            zm.inMeetingServiceListener('onChatReceived', function(data) {
              if (!data) return;
              var s = 'Instructor';
              if (typeof data.sender === 'string') s = data.sender;
              else if (data.sender && data.sender.name) s = data.sender.name;
              else if (data.senderName) s = data.senderName;

              var m = data.message || data.content || '';
              if (!m) return;

              var lowerS = s.toLowerCase();
              if (lowerS === 'you' || lowerS === 'me') return;
              if (window.__premierSentMessages && window.__premierSentMessages.has(m)) return;

              var sig = s + ':::' + m;
              if (scrapedSignatures.has(sig)) return;
              scrapedSignatures.add(sig);

              postToFlutter({
                type: 'chatReceived',
                sender: s,
                message: m,
                timestamp: new Date().toLocaleTimeString([], {hour: '2-digit', minute: '2-digit'})
              });
            });
          } catch(e) {}

          postToFlutter({ type: 'bridgeReady' });
        }

        // 2. Ensure Zoom's native chat panel is mounted in background
        function ensureZoomChatMounted() {
          var hasChat = document.querySelector('.chat-box, #wc-container-right, .chat-container, [class*="chat-box"], textarea[placeholder*="chat" i], textarea[placeholder*="message" i]');
          if (!hasChat) {
            var btns = Array.from(document.querySelectorAll('button, [role="button"]'));
            var chatBtn = btns.find(function(b) {
              var label = (b.getAttribute('aria-label') || b.innerText || '').toLowerCase();
              return label.indexOf('chat') !== -1;
            });
            if (chatBtn) {
              chatBtn.click();
            }
          }
        }

        // 3. Keep Zoom's native chat UI invisible and offscreen so it never covers the video
        function hideNativeZoomChat() {
          var els = document.querySelectorAll('#wc-container-right, .chat-box, .chat-container, [class*="chat-container"], [class*="chat-notification"], [class*="chat-rt"]');
          els.forEach(function(el) {
            el.style.setProperty('position', 'fixed', 'important');
            el.style.setProperty('opacity', '0', 'important');
            el.style.setProperty('pointer-events', 'none', 'important');
            el.style.setProperty('z-index', '-999', 'important');
            el.style.setProperty('left', '-9999px', 'important');
            el.style.setProperty('top', '-9999px', 'important');
          });
        }

        // 4. Live DOM Scraper for Zoom chat messages
        function scrapeZoomChat() {
          var selectors = [
            '.chat-item',
            '.chat-message',
            '[class*="chat-item"]',
            '[class*="chat-message"]',
            '.chat-rt__content',
            '.chat-notification',
            '[class*="chat-notification"]',
            '[class*="chat-box__chat-message"]',
            'div[role="listitem"]',
            '.chat-virtual-item'
          ];
          var items = document.querySelectorAll(selectors.join(', '));
          items.forEach(function(item) {
            if (item.__premierScraped) return;

            // Extract sender
            var senderEl = item.querySelector('.chat-item__sender, [class*="sender"], [class*="name"], strong, b, h4, [class*="user"]');
            var sender = senderEl ? (senderEl.innerText || senderEl.textContent || '').trim() : '';

            // Extract message text
            var msgEl = item.querySelector('.chat-item__chat-info-msg, [class*="chat-info-msg"], [class*="message-text"], [class*="content"], p');
            var message = msgEl ? (msgEl.innerText || msgEl.textContent || '').trim() : '';

            if (!message && item.innerText) {
              var full = item.innerText.trim();
              if (sender && full.startsWith(sender)) {
                message = full.substring(sender.length).trim();
              } else {
                message = full;
              }
            }

            if (!message || message.length === 0) return;

            // Normalize sender
            if (sender) {
              sender = sender.replace(/\\s*(to\\s+.*|:|direct message|privately)\\s*\$/i, '').trim();
            }
            if (!sender) sender = 'Instructor';

            // Filter out own messages
            var lowerSender = sender.toLowerCase();
            if (lowerSender === 'you' || lowerSender === 'me' || lowerSender === 'myself') {
              item.__premierScraped = true;
              return;
            }
            if (window.__premierSentMessages && window.__premierSentMessages.has(message)) {
              item.__premierScraped = true;
              return;
            }

            // Deduplicate
            var sig = sender + ':::' + message;
            if (scrapedSignatures.has(sig)) {
              item.__premierScraped = true;
              return;
            }

            scrapedSignatures.add(sig);
            item.__premierScraped = true;

            var timeEl = item.querySelector('.chat-item__time, [class*="time"]');
            var timestamp = timeEl ? (timeEl.innerText || '').trim() : '';
            if (!timestamp) {
              timestamp = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }

            postToFlutter({
              type: 'chatReceived',
              sender: sender,
              message: message,
              timestamp: timestamp
            });
          });
        }

        // Active polling loop
        setInterval(function() {
          hookZoomMtg();
          ensureZoomChatMounted();
          hideNativeZoomChat();
          scrapeZoomChat();
        }, 600);

        // MutationObserver for instant reactivity when DOM nodes are added
        try {
          var observer = new MutationObserver(function() {
            scrapeZoomChat();
            hideNativeZoomChat();
          });
          observer.observe(document.body, { childList: true, subtree: true });
        } catch(e) {}
      })();
    ''';
    c.runJavaScript(bridgeJs).catchError((e) {
      debugPrint("Error injecting Zoom bridge JS: $e");
    });
  }

  // ─── Handle incoming bridge messages from Zoom SDK ─────────────────────────
  void _handleBridgeMessage(String message) {
    try {
      final data = jsonDecode(message);
      final String type = data['type'] ?? '';
      switch (type) {
        case 'audioState':
          final bool muted = data['muted'] ?? false;
          if (mounted && _isMuted != muted) {
            setState(() {
              _isMuted = muted;
            });
          }
          break;
        case 'videoState':
          final bool videoOff = data['videoOff'] ?? false;
          if (mounted && _isVideoOff != videoOff) {
            setState(() {
              _isVideoOff = videoOff;
            });
          }
          break;
        case 'chatReceived':
          if (mounted) {
            final String sender = data['sender']?.toString() ?? 'Instructor';
            final String msgText = data['message']?.toString() ?? '';
            final String timeStr = data['timestamp']?.toString() ?? '';

            // Guard against duplicate messages
            final isDuplicate = _chatMessages.any(
              (m) => m['message'] == msgText && m['sender'] == sender,
            );
            if (!isDuplicate && msgText.isNotEmpty) {
              setState(() {
                _chatMessages.add({
                  'sender': sender,
                  'message': msgText,
                  'timestamp': timeStr,
                  'isMe': 'false',
                });
              });
              _chatUpdateNotifier.value++;
              _chatModalSetState?.call(() {});
              // Auto-scroll chat to bottom
              Future.delayed(const Duration(milliseconds: 100), () {
                if (_chatScrollController.hasClients) {
                  _chatScrollController.animateTo(
                    _chatScrollController.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                  );
                }
              });
            }
          }
          break;
        case 'preJoinState':
          final bool inPreJoin = data['inPreJoin'] ?? false;
          if (mounted && _isPreJoin != inPreJoin) {
            setState(() {
              _isPreJoin = inPreJoin;
            });
          }
          break;
        case 'bridgeReady':
          debugPrint('Zoom JS Bridge connected successfully.');
          break;
      }
    } catch (e) {
      debugPrint('Error parsing bridge message: $e');
    }
  }

  // ─── Bug 1 Fix: Correct mic toggle ─────────────────────────────────────────
  // Read the actual Zoom mute state from the DOM button label, then
  // click the correct button. The bridge listener will sync _isMuted.
  void _toggleAudio() {
    _resetInactivityTimer();
    setState(() {
      _isMuted = !_isMuted;
    });
    _controller?.runJavaScript('''
      (function() {
        var muteBtn = document.querySelector('button[aria-label="Mute"], button[aria-label*="Mute"], button[aria-label*="mute"]');
        var unmuteBtn = document.querySelector('button[aria-label="Unmute"], button[aria-label*="Unmute"], button[aria-label*="unmute"]');
        // Inverted: click unmute first, then mute
        if (unmuteBtn) { unmuteBtn.click(); return; }
        if (muteBtn) { muteBtn.click(); return; }
        var btn = document.querySelector('button[aria-label*="Audio"], button[aria-label*="audio"]');
        if (btn) btn.click();
      })();
    ''');
  }

  void _toggleVideo() {
    _resetInactivityTimer();
    setState(() {
      _isVideoOff = !_isVideoOff;
    });
    _controller?.runJavaScript('''
      (function() {
        var stopBtn = document.querySelector('button[aria-label="Stop Video"], button[aria-label*="Stop Video"], button[aria-label*="stop video"]');
        var startBtn = document.querySelector('button[aria-label="Start Video"], button[aria-label*="Start Video"], button[aria-label*="start video"]');
        // Inverted: click start first, then stop
        if (startBtn) { startBtn.click(); return; }
        if (stopBtn) { stopBtn.click(); return; }
        var btn = document.querySelector('button[aria-label*="Video"], button[aria-label*="video"], button[aria-label*="Camera"]');
        if (btn) btn.click();
      })();
    ''');
  }

  // ─── Speaker/Audio Mute Toggle ─────────────────────────────────────────────
  void _toggleSpeaker() {
    _resetInactivityTimer();
    final newSpeakerState = !_isSpeakerOn;
    setState(() {
      _isSpeakerOn = newSpeakerState;
    });
    // In HTML5/WebRTC, sound plays through <audio> and <video> elements.
    // Directly setting muted and volume controls the sound stream immediately.
    _controller?.runJavaScript('''
      (function() {
        var isMuted = ${!newSpeakerState};
        var mediaElements = document.querySelectorAll('audio, video');
        mediaElements.forEach(function(el) {
          el.muted = isMuted;
          if (isMuted) {
            el.volume = 0;
          } else {
            el.volume = 1;
          }
        });
      })();
    ''');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newSpeakerState ? 'Meeting sound unmuted 🔊' : 'Meeting sound muted 🔇'),
        duration: const Duration(seconds: 2),
        backgroundColor: newSpeakerState ? AppColors.primaryGreen : const Color(0xFF334155),
      ),
    );
  }

  // ─── Bug 6 Fix: Wire camera switch button ──────────────────────────────────
  void _switchCamera() {
    _resetInactivityTimer();
    _controller?.runJavaScript('''
      (function() {
        // Try Zoom's native camera switch button
        var switchBtn = document.querySelector('button[aria-label*="Switch Camera"], button[aria-label*="switch camera"]');
        if (switchBtn) { switchBtn.click(); return; }
        // Fallback: try the video dropdown arrow and cycle through devices
        var videoDropdown = document.querySelector('.footer-button__video-dropdown, [class*="video-option-arrow"]');
        if (videoDropdown) { videoDropdown.click(); return; }
        // Last resort: cycle via mediaDevices API
        if (navigator.mediaDevices && navigator.mediaDevices.enumerateDevices) {
          navigator.mediaDevices.enumerateDevices().then(function(devices) {
            var cameras = devices.filter(function(d) { return d.kind === 'videoinput'; });
            if (cameras.length > 1) {
              // Try clicking camera device options in the Zoom settings popup
              var cameraItems = document.querySelectorAll('[class*="camera-device"], [class*="video-device"]');
              if (cameraItems.length > 1) {
                cameraItems[1].click();
              }
            }
          });
        }
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
              backgroundColor: const Color(0xFFE11D48),
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

  void _showParticipantsDialog() {
    _resetInactivityTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Participants',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildParticipantTile('Instructor', 'Host', Icons.school, true),
            const Divider(color: Colors.white12),
            _buildParticipantTile('You', 'Participant', Icons.person, false),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantTile(String name, String role, IconData icon, bool isHost) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isHost ? AppColors.primaryGreen : const Color(0xFF334155),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(role, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ),
          Icon(
            _isMuted ? Icons.mic_off : Icons.mic,
            size: 16,
            color: _isMuted ? Colors.redAccent : Colors.white70,
          ),
        ],
      ),
    );
  }

  // ─── Live Chat Send ────────────────────────────────────────────────────────
  void _sendChatMessage(String message) {
    if (message.trim().isEmpty) return;
    final escapedMessage = message.replaceAll("'", "\\'").replaceAll('\n', ' ');
    _controller?.runJavaScript('''
      (function() {
        window.__premierSentMessages = window.__premierSentMessages || new Set();
        window.__premierSentMessages.add('$escapedMessage');

        // Strategy 1: ZoomMtg SDK API if available
        try {
          var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
          if (zm && zm.sendChat) {
            zm.sendChat({
              message: '$escapedMessage',
              userId: 0,
              success: function() {},
              error: function() {}
            });
            return;
          }
        } catch(e) {}

        // Strategy 2: Directly type into textarea if available
        function tryTypeAndSend() {
          var chatInput = document.querySelector('textarea.chat-box__chat-textarea, .chat-receiver-list textarea, textarea[class*="chat"], textarea[placeholder*="chat" i], textarea[placeholder*="message" i], textarea');
          if (chatInput) {
            var nativeSetter = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value');
            if (nativeSetter && nativeSetter.set) {
              nativeSetter.set.call(chatInput, '$escapedMessage');
            } else {
              chatInput.value = '$escapedMessage';
            }
            chatInput.dispatchEvent(new Event('input', { bubbles: true }));
            chatInput.dispatchEvent(new Event('change', { bubbles: true }));
            setTimeout(function() {
              var sendBtn = document.querySelector('button[class*="send"], button[aria-label*="send" i], .chat-box__send-btn');
              if (sendBtn) {
                sendBtn.click();
              } else {
                chatInput.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true }));
              }
            }, 100);
            return true;
          }
          return false;
        }

        if (!tryTypeAndSend()) {
          // Open Zoom's chat panel by clicking the footer Chat button
          var allBtns = Array.from(document.querySelectorAll('button, [role="button"]'));
          var chatBtn = allBtns.find(function(b) {
            var label = (b.getAttribute('aria-label') || b.innerText || '').toLowerCase();
            return label.indexOf('chat') !== -1;
          });
          if (chatBtn) {
            chatBtn.click();
            setTimeout(tryTypeAndSend, 300);
          }
        }
      })();
    ''');
    // Add to local messages immediately for responsive UI
    setState(() {
      _chatMessages.add({
        'sender': 'You',
        'message': message,
        'timestamp': TimeOfDay.now().format(context),
        'isMe': 'true',
      });
    });
    _chatController.clear();
    _chatUpdateNotifier.value++;
    _chatModalSetState?.call(() {});
    // Auto-scroll
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showChatDialog() {
    _resetInactivityTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          _chatModalSetState = setModalState;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.chat_bubble_outline, color: AppColors.primaryGreen, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Live Chat',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Chat messages list wrapped in ValueListenableBuilder for instantaneous reactivity
                ValueListenableBuilder<int>(
                  valueListenable: _chatUpdateNotifier,
                  builder: (context, _, __) {
                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _chatMessages.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Text(
                                  'No messages yet. Start the conversation!',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5, height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _chatScrollController,
                              padding: const EdgeInsets.all(10),
                              itemCount: _chatMessages.length,
                              itemBuilder: (context, index) {
                                final msg = _chatMessages[index];
                                final isMe = msg['isMe'] == 'true';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Align(
                                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? AppColors.primaryGreen.withValues(alpha: 0.2)
                                            : const Color(0xFF334155),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            msg['sender'] ?? '',
                                            style: TextStyle(
                                              color: isMe ? AppColors.primaryGreen : Colors.white70,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            msg['message'] ?? '',
                                            style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            msg['timestamp'] ?? '',
                                            style: const TextStyle(color: Colors.white38, fontSize: 9),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Chat input bar — styled dark, explicit fillColor, Autofill disabled to prevent white bar
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF334155), width: 1.2),
                        ),
                        alignment: Alignment.center,
                        child: TextField(
                          controller: _chatController,
                          autofillHints: null,
                          enableSuggestions: false,
                          autocorrect: false,
                          keyboardType: TextInputType.text,
                          textInputAction: TextInputAction.send,
                          cursorColor: AppColors.primaryGreen,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w400,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            filled: true,
                            fillColor: Color(0xFF1E293B),
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                          onSubmitted: (value) {
                            _sendChatMessage(value);
                            setModalState(() {});
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          _sendChatMessage(_chatController.text);
                          setModalState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      _chatModalSetState = null;
    });
  }

  // ─── Raise Hand Wired to Zoom ──────────────────────────────────────────────
  void _toggleRaiseHand() {
    _resetInactivityTimer();
    final willRaise = !_isHandRaised;
    setState(() {
      _isHandRaised = willRaise;
    });
    _controller?.runJavaScript('''
      (function() {
        // Strategy 1: ZoomMtg SDK API
        try {
          if (typeof ZoomMtg !== 'undefined') {
            if ($willRaise && ZoomMtg.raiseHand) {
              ZoomMtg.raiseHand({ success: function() {}, error: function() {} });
              return;
            } else if (!$willRaise && ZoomMtg.lowerHand) {
              ZoomMtg.lowerHand({ success: function() {}, error: function() {} });
              return;
            }
          }
        } catch(e) {}

        // Strategy 2: Direct button click if already in DOM
        var targetAria = $willRaise ? 'raise hand' : 'lower hand';
        var allBtns = Array.from(document.querySelectorAll('button, [role="button"]'));
        var directBtn = allBtns.find(function(b) {
          var label = (b.getAttribute('aria-label') || b.innerText || '').toLowerCase();
          return label.indexOf(targetAria) !== -1;
        });
        if (directBtn) {
          directBtn.click();
          return;
        }

        // Strategy 3: Open Reactions menu first, then click Raise/Lower Hand
        var reactionsBtn = allBtns.find(function(b) {
          var label = (b.getAttribute('aria-label') || b.innerText || '').toLowerCase();
          return label.indexOf('reaction') !== -1;
        });
        if (reactionsBtn) {
          reactionsBtn.click();
          setTimeout(function() {
            var btnsAfter = Array.from(document.querySelectorAll('button, [role="button"], .reaction-menu__item, [class*="reaction"]'));
            var handBtn = btnsAfter.find(function(b) {
              var l = (b.getAttribute('aria-label') || b.innerText || '').toLowerCase();
              return l.indexOf('hand') !== -1;
            });
            if (handBtn) {
              handBtn.click();
            }
          }, 150);
        }
      })();
    ''');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(willRaise ? 'Hand raised ✋' : 'Hand lowered'),
        duration: const Duration(seconds: 2),
        backgroundColor: willRaise ? AppColors.primaryGreen : const Color(0xFF334155),
      ),
    );
  }

  void _showMoreOptions() {
    _resetInactivityTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                _isHandRaised ? Icons.pan_tool : Icons.pan_tool_outlined,
                color: _isHandRaised ? Colors.amber : Colors.white,
              ),
              title: Text(
                _isHandRaised ? 'Lower Hand' : 'Raise Hand',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _toggleRaiseHand();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white),
              title: const Text('Class Information', style: TextStyle(color: Colors.white, fontSize: 14)),
              subtitle: Text(widget.title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bug 6 Fix: Show meeting info dialog ───────────────────────────────────
  void _showMeetingInfo() {
    _resetInactivityTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Meeting Information',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.class_outlined, 'Class', widget.title),
            const SizedBox(height: 10),
            _buildInfoRow(Icons.key, 'Class ID', widget.classId),
            const SizedBox(height: 10),
            _buildInfoRow(
              Icons.circle,
              'Status',
              'Live · Active',
              valueColor: AppColors.primaryGreen,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              _isMuted ? Icons.mic : Icons.mic_off,
              'Microphone',
              _isMuted ? 'Active' : 'Muted',
              valueColor: _isMuted ? AppColors.primaryGreen : Colors.redAccent,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              _isVideoOff ? Icons.videocam : Icons.videocam_off,
              'Camera',
              _isVideoOff ? 'On' : 'Off',
              valueColor: _isVideoOff ? AppColors.primaryGreen : Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _chatUpdateNotifier.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
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
        if (orientation == Orientation.portrait) {
          return _buildPortraitUI();
        } else {
          return _buildLandscapeUI();
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

  // ─── Landscape UI (Reference Video Matched Layout) ─────────────────────────
  Widget _buildLandscapeUI() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // 1. Fullscreen Video — fills the entire screen edge-to-edge without letterboxing
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: _buildVideoView(),
                ),
              ),

              // 2. Full-Screen Tap Detector (disabled during pre-join so native touch scrolling is 100% unimpeded)
              if (!_isPreJoin)
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('video_gesture_detector'),
                    behavior: HitTestBehavior.translucent,
                    onTap: _toggleControls,
                    child: Container(
                      color: Colors.transparent,
                    ),
                  ),
                ),

              // 3. Auto-Hiding Floating Controls (Top Header & Bottom Toolbar - hidden during pre-join)
              if (!_isPreJoin)
                IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: AnimatedOpacity(
                    opacity: _controlsVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Stack(
                      children: [
                        // Top Bar Overlay
                        _buildTopOverlay(),

                        // Bottom Floating Pill Toolbar
                        _buildBottomOverlay(),
                      ],
                    ),
                  ),
                ),
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
    return WebViewWidget(
      controller: _controller!,
      gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
        Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer(),
        ),
        Factory<HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(),
        ),
        Factory<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
        ),
        Factory<ScaleGestureRecognizer>(
          () => ScaleGestureRecognizer(),
        ),
      },
    );
  }

  // ─── Top Overlay Bar (Modeled After Reference Video) ───────────────────────
  Widget _buildTopOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.4),
              Colors.transparent,
            ],
          ),
        ),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Back chevron / leave button
              InkWell(
                onTap: () => _handleLeaveClass(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 10),

              // Title & Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Text(
                          'Live Classroom · Active',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Loading spinner
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.0),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                      strokeWidth: 2,
                    ),
                  ),
                ),

              // Right Action Buttons
              // Speaker toggle
              IconButton(
                icon: Icon(
                  _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _toggleSpeaker,
              ),

              // Bug 6 Fix: Camera Switch toggle — wired to Zoom SDK
              IconButton(
                icon: const Icon(
                  Icons.cameraswitch_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _switchCamera,
              ),

              // Meeting info button
              IconButton(
                icon: const Icon(
                  Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _showMeetingInfo,
              ),

              const SizedBox(width: 6),

              // Red "Leave" / "End" Pill Button (matches Reference Video top-right)
              InkWell(
                onTap: () => _handleLeaveClass(context),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE11D48).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Leave',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Bottom Floating Capsule Toolbar (Modeled After Reference Video) ──────
  Widget _buildBottomOverlay() {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xEE18181B), // Dark frosted capsule background
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Mute / Unmute (Inverted)
              _buildToolbarItem(
                icon: _isMuted ? Icons.mic : Icons.mic_off,
                label: _isMuted ? 'Mute' : 'Unmute',
                isAlert: !_isMuted,
                onTap: _toggleAudio,
              ),
              const SizedBox(width: 14),

              // 2. Stop Video / Start Video (Inverted)
              _buildToolbarItem(
                icon: _isVideoOff ? Icons.videocam : Icons.videocam_off,
                label: _isVideoOff ? 'Stop video' : 'Start video',
                isAlert: !_isVideoOff,
                onTap: _toggleVideo,
              ),
              const SizedBox(width: 14),

              // 3. Participants
              _buildToolbarItem(
                icon: Icons.people_outline,
                label: 'Participants',
                onTap: _showParticipantsDialog,
              ),
              const SizedBox(width: 14),

              // 4. Chat
              _buildToolbarItem(
                icon: Icons.chat_bubble_outline,
                label: 'Chat',
                onTap: _showChatDialog,
              ),
              const SizedBox(width: 14),

              // 5. More
              _buildToolbarItem(
                icon: Icons.more_horiz,
                label: 'More',
                onTap: _showMoreOptions,
              ),

              // STRICT FEATURE EXCLUSIONS:
              // NO "Share Screen" button.
              // NO "Zoom AI Companion" button.
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolbarItem({
    required IconData icon,
    required String label,
    bool isAlert = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        _resetInactivityTimer();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isAlert ? Colors.redAccent : Colors.white,
              size: 20,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isAlert ? Colors.redAccent : Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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
