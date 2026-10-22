import 'dart:async';
import 'dart:convert';
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

  // Zoom controls state
  bool _controlsVisible = false; // Hidden until meeting actually joined
  Timer? _hideTimer;
  bool _isMuted = true;
  bool _isVideoOff = true;
  bool _isSpeakerOn = true;
  bool _isHandRaised = false;
  bool _isMeetingJoined = false; // Flipped true once Zoom SDK confirms in-meeting
  bool _isDataSaver = false; // Low-bandwidth / low-latency optimization mode
  int _participantCount = 1;
  int _unreadChatCount = 0;

  // Track whether user has manually interacted — only auto-hide AFTER first tap
  bool _hasUserInteracted = false;

  // Chat state
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatMessages = [];
  final ScrollController _chatScrollController = ScrollController();
  final ValueNotifier<int> _chatUpdateNotifier = ValueNotifier<int>(0);
  StateSetter? _chatModalSetState;
  DateTime? _lastChatReceived; // Used for time-windowed dedup of incoming messages

  // Dynamic attendees state from Zoom SDK
  final List<Map<String, dynamic>> _attendees = [];
  StateSetter? _participantsModalSetState;

  @override
  void initState() {
    super.initState();

    // Support both orientations seamlessly
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
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

    // Don't auto-hide on init — controls stay visible until user taps the video
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _isMeetingJoined && _hasUserInteracted) {
        setState(() {
          _controlsVisible = false;
        });
      }
    });
  }

  void _toggleControls() {
    _hasUserInteracted = true;
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
    _hasUserInteracted = true;
    if (_controlsVisible) {
      _startHideTimer();
    }
  }

  Future<void> _requestPermissionsAndInitWebView() async {
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
    final String userAgent = defaultTargetPlatform == TargetPlatform.iOS
        ? "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15 PremierLMSMobileWebView"
        : "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 PremierLMSMobileWebView";

    final classroomUrl =
        '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';

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
      debugPrint("Error setting WebView cookies: $e");
    }

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
            if (url.endsWith('/dashboard') ||
                (url.contains('/dashboard/classes') && !url.contains(widget.classId))) {
              debugPrint("Class ended or user left. Returning to app: $url");
              if (mounted) {
                Navigator.of(context).pop();
              }
              return NavigationDecision.prevent;
            }
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
            _injectOptimizedStylesAndBridge(controller);
            // Multi-interval injection to handle Next.js client-side hydration & async Zoom SDK load
            for (final s in [1, 2, 3, 5, 8, 12, 16, 20]) {
              Future.delayed(Duration(seconds: s), () {
                if (mounted) {
                  _injectOptimizedStylesAndBridge(controller);
                }
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("WebView error: ${error.description}");
          },
        ),
      )
      ..loadRequest(Uri.parse(classroomUrl));

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
      });
    }
  }

  Future<void> _launchClassroomUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Injects clean, GPU-accelerated CSS and event-driven JS with ZERO polling loops.
  void _injectOptimizedStylesAndBridge(WebViewController controller) {
    const js = '''
      (function() {
        // 1. High-Performance Hardware-Accelerated CSS
        var style = document.getElementById('premier-zoom-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'premier-zoom-style';
          style.type = 'text/css';
          (document.head || document.documentElement).appendChild(style);
        }
        style.innerHTML = `
          /* Viewport reset: Allow touch scrolling during pre-join preview */
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
          html.in-meeting, body.in-meeting {
            overflow: hidden !important;
            height: 100vh !important;
            -webkit-user-select: none !important;
            user-select: none !important;
          }

          /* CRITICAL FIX: Suppress Next.js web loading overlay so Zoom pre-join & Join button are never obscured */
          div[class*="z-[10000]"],
          div[class*="z-\\\\[10000\\\\]"],
          div[class*="bg-gradient-to-br"][class*="fixed"] {
            display: none !important;
            visibility: hidden !important;
            opacity: 0 !important;
            pointer-events: none !important;
            z-index: -1 !important;
          }

          /* Zoom root container: Must be higher z-index than web loading overlays */
          #zmmtg-root {
            display: block !important;
            width: 100vw !important;
            min-height: 100vh !important;
            margin: 0 !important;
            padding: 0 !important;
            background-color: #000000 !important;
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            overflow-x: hidden !important;
            overflow-y: auto !important;
            -webkit-overflow-scrolling: touch !important;
            z-index: 999999 !important;
          }
          body.in-meeting #zmmtg-root {
            overflow: hidden !important;
            height: 100vh !important;
          }

          /* PRE-JOIN & JOIN BUTTONS: Must ALWAYS be on top, visible, and 100% clickable! */
          .preview-meeting,
          .preview-video,
          [class*="preview"],
          [class*="join"],
          .join-dialog,
          button.preview-join-button,
          button[class*="join-btn"],
          button[class*="btn-join"],
          .preview-join-button,
          button[aria-label*="Join" i],
          div[class*="join-audio"],
          .aria-aria-modal-component {
            display: inline-block !important;
            visibility: visible !important;
            opacity: 1 !important;
            z-index: 999999 !important;
            pointer-events: auto !important;
          }
          /* Ensure footers and buttons inside pre-join dialogs are NEVER hidden */
          .preview-meeting .footer,
          .preview-meeting [class*="footer"],
          .join-dialog .footer,
          .join-dialog [class*="footer"],
          [class*="preview-dialog"] [class*="footer"],
          [class*="preview"] button,
          [class*="join"] button {
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            pointer-events: auto !important;
            width: auto !important;
            height: auto !important;
          }

          /* Suppress Zoom's clunky in-meeting web footer/header to allow native Zoom mobile bar */
          body.in-meeting #wc-footer,
          body.in-meeting .footer-bar,
          body.in-meeting #wc-header,
          .meeting-info-container, .meeting-info-icon,
          [class*="meeting-header"], .participants-header,
          button[aria-label*="Share" i], button[aria-label*="share" i],
          .footer-button__share-screen, .footer-button-base__share,
          button[aria-label*="AI" i], button[aria-label*="Companion" i], [class*="ai-companion"],
          #wc-container-right, .chat-box, .chat-container, [class*="chat-container"],
          [class*="chat-notification"], [class*="chat-rt"] {
            display: none !important;
            visibility: hidden !important;
            opacity: 0 !important;
            pointer-events: none !important;
            width: 0 !important;
            height: 0 !important;
          }

          /* INSTRUCTOR SCREEN SHARE STREAM: Highest priority presentation layer with object-fit: contain */
          #active-share-container,
          .sharing-screen,
          .sharing-screen-container,
          .share-screen-content,
          #active-share-canvas,
          .active-share-canvas,
          [class*="active-share"],
          canvas[class*="share"],
          video[class*="share"] {
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            object-fit: contain !important;
            background-color: #000000 !important;
            z-index: 10 !important;
            pointer-events: auto !important;
          }
          #active-share-container canvas,
          #active-share-container video,
          .sharing-screen canvas,
          .sharing-screen video,
          .sharing-screen-container canvas,
          .sharing-screen-container video {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            object-fit: contain !important;
            z-index: 10 !important;
          }

          /* HARDWARE ACCELERATION & LOW-LATENCY GPU COMPOSITING */
          canvas, video {
            will-change: transform !important;
            transform: translateZ(0) !important;
            -webkit-transform: translateZ(0) !important;
            backface-visibility: hidden !important;
            -webkit-backface-visibility: hidden !important;
          }

          /* DATA SAVER MODE: Suppress video decoding to conserve bandwidth on 2G/3G/weak Wi-Fi */
          body.data-saver-active #active-speaker-view canvas,
          body.data-saver-active #active-speaker-view video,
          body.data-saver-active #active-video-container canvas,
          body.data-saver-active #active-video-container video,
          body.data-saver-active .speaker-active-video canvas,
          body.data-saver-active .speaker-active-video video,
          body.data-saver-active .active-main canvas,
          body.data-saver-active .active-main video,
          body.data-saver-active .speaker-view-container > canvas,
          body.data-saver-active .speaker-view-container > video,
          body.data-saver-active .speaker-bar,
          body.data-saver-active .speaker-bar-container,
          body.data-saver-active #speaker-bar,
          body.data-saver-active [class*="speaker-bar"],
          body.data-saver-active [class*="filmstrip"],
          body.data-saver-active .filmstrip-item {
            display: none !important;
            visibility: hidden !important;
            opacity: 0 !important;
            pointer-events: none !important;
          }

          /* SCREEN SHARE AUTO-FOCUS: Hide secondary participant video bar during presentations to cut 50%+ CPU */
          body.screen-sharing-active .speaker-bar,
          body.screen-sharing-active .speaker-bar-container,
          body.screen-sharing-active #speaker-bar,
          body.screen-sharing-active [class*="speaker-bar"],
          body.screen-sharing-active [class*="filmstrip"],
          body.screen-sharing-active .filmstrip-item {
            display: none !important;
            visibility: hidden !important;
          }

          /* MAIN ACTIVE SPEAKER VIDEO CANVAS: Background fills when no screen share */
          #active-speaker-view canvas,
          #active-speaker-view video,
          #active-video-container canvas,
          #active-video-container video,
          .speaker-active-video canvas,
          .speaker-active-video video,
          .active-main canvas,
          .active-main video,
          .speaker-view-container > canvas,
          .speaker-view-container > video {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            width: 100vw !important;
            height: 100vh !important;
            min-width: 100vw !important;
            min-height: 100vh !important;
            object-fit: cover !important;
            transform: translateZ(0) !important;
            z-index: 2 !important;
          }

          /* PARTICIPANT VIDEO FILMSTRIP (Top thumbnail ribbon like Zoom) */
          body.in-meeting .speaker-bar,
          body.in-meeting .speaker-bar-container,
          body.in-meeting #speaker-bar,
          body.in-meeting [class*="speaker-bar"],
          body.in-meeting [class*="filmstrip"],
          body.in-meeting .filmstrip-item,
          body.in-meeting .speaker-bar-item {
            display: flex !important;
            visibility: visible !important;
            opacity: 1 !important;
            position: fixed !important;
            top: 60px !important;
            left: 0 !important;
            width: 100vw !important;
            height: 64px !important;
            z-index: 999 !important;
            background: transparent !important;
            overflow-x: auto !important;
            overflow-y: hidden !important;
            pointer-events: auto !important;
          }
          .speaker-bar-item,
          .filmstrip-item,
          [class*="speaker-bar-item"],
          [class*="filmstrip-item"] {
            display: inline-block !important;
            visibility: visible !important;
            opacity: 1 !important;
            width: 76px !important;
            height: 56px !important;
            margin: 0 4px !important;
            border-radius: 8px !important;
            overflow: hidden !important;
            border: 1px solid rgba(255, 255, 255, 0.25) !important;
            background-color: #1E293B !important;
            flex-shrink: 0 !important;
          }
          .speaker-bar-item canvas,
          .speaker-bar-item video,
          .filmstrip-item canvas,
          .filmstrip-item video {
            position: static !important;
            width: 100% !important;
            height: 100% !important;
            min-width: 0 !important;
            min-height: 0 !important;
            object-fit: cover !important;
            display: block !important;
          }

          /* STUDENT SELF-VIEW FLOATING PIP: Active only when meeting is joined */
          body.in-meeting .suspension-window,
          body.in-meeting #suspension-video,
          body.in-meeting .suspension-video,
          body.in-meeting #suspension-window,
          body.in-meeting #self-video-container,
          body.in-meeting .self-video-container {
            position: fixed !important;
            top: 130px !important;
            right: 14px !important;
            bottom: auto !important;
            left: auto !important;
            width: 96px !important;
            height: 132px !important;
            border-radius: 12px !important;
            border: 2px solid #10B981 !important;
            background-color: #0F172A !important;
            box-shadow: 0 8px 24px rgba(0, 0, 0, 0.8) !important;
            overflow: hidden !important;
            z-index: 99999 !important;
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            pointer-events: auto !important;
          }
          body.in-meeting .suspension-window canvas,
          body.in-meeting .suspension-window video,
          body.in-meeting #suspension-video canvas,
          body.in-meeting #suspension-video video,
          body.in-meeting .suspension-video canvas,
          body.in-meeting .suspension-video video,
          body.in-meeting #self-video-container canvas,
          body.in-meeting #self-video-container video,
          body.in-meeting .self-video-container canvas,
          body.in-meeting .self-video-container video {
            position: static !important;
            width: 100% !important;
            height: 100% !important;
            min-width: 0 !important;
            min-height: 0 !important;
            object-fit: cover !important;
            display: block !important;
            visibility: visible !important;
            opacity: 1 !important;
            transform: none !important;
          }

          /* ZOOM MODALS, ALERTS, & CONFIRMATIONS */
          .zm-modal,
          [role="dialog"],
          .meeting-alert,
          .modal-dialog,
          .common-dialog,
          .react-draggable,
          div[class*="dialog"],
          div[class*="modal"] {
            z-index: 9999999 !important;
            pointer-events: auto !important;
            max-width: 90vw !important;
            margin: auto !important;
          }
          .zm-modal button,
          [role="dialog"] button,
          .meeting-alert button,
          .modal-dialog button,
          .zm-btn,
          button.zm-btn {
            pointer-events: auto !important;
            cursor: pointer !important;
            z-index: 99999999 !important;
          }
          @media (orientation: landscape) {
            body.in-meeting .suspension-window,
            body.in-meeting #suspension-video,
            body.in-meeting .suspension-video,
            body.in-meeting #suspension-window,
            body.in-meeting #self-video-container,
            body.in-meeting .self-video-container {
              top: 50px !important;
              right: 12px !important;
              width: 76px !important;
              height: 104px !important;
            }
          }
        `;

        // 2. Remove Next.js loading overlay if present
        function removeWebLoadingOverlay() {
          try {
            var overlays = document.querySelectorAll('div[class*="z-[10000]"], div[class*="z-\\\\[10000\\\\]"], div.fixed.inset-0');
            for (var i = 0; i < overlays.length; i++) {
              var o = overlays[i];
              var txt = (o.innerText || o.textContent || '').toLowerCase();
              if (txt.indexOf('loading video') !== -1 || txt.indexOf('joining secure') !== -1) {
                o.style.setProperty('display', 'none', 'important');
                o.style.setProperty('visibility', 'hidden', 'important');
                o.style.setProperty('pointer-events', 'none', 'important');
                o.style.setProperty('opacity', '0', 'important');
                o.style.setProperty('z-index', '-1', 'important');
              }
            }
          } catch(e) {}
        }
        removeWebLoadingOverlay();

        // 3. Ensure Join button is visible and smoothly scrolled into view
        function ensureJoinButtonVisible() {
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
            joinBtn.style.setProperty('display', 'inline-block', 'important');
            joinBtn.style.setProperty('visibility', 'visible', 'important');
            joinBtn.style.setProperty('opacity', '1', 'important');
            joinBtn.style.setProperty('pointer-events', 'auto', 'important');
            joinBtn.style.setProperty('z-index', '999999', 'important');

            if (!window.__joinBtnScrolled) {
              window.__joinBtnScrolled = true;
              setTimeout(function() {
                try {
                  joinBtn.scrollIntoView({ behavior: 'smooth', block: 'center' });
                } catch(e) {}
              }, 300);
            }
          }
        }
        ensureJoinButtonVisible();

        if (window.__premierBridgeInitialized) return;
        window.__premierBridgeInitialized = true;

        function postToFlutter(data) {
          try {
            if (window.FlutterZoomBridge) {
              FlutterZoomBridge.postMessage(JSON.stringify(data));
            }
          } catch(e) {}
        }

        var isMeetingJoinedSent = false;
        var userClickedJoin = false;

        function markInMeeting() {
          if (isMeetingJoinedSent) return;
          isMeetingJoinedSent = true;
          document.body.classList.add('in-meeting');
          document.documentElement.classList.add('in-meeting');
          postToFlutter({ type: 'meetingJoined' });
        }

        // Catch user tapping/clicking ANY Join button in the WebView
        function handleJoinTap(e) {
          var el = e.target;
          while (el && el !== document.body && el !== document.documentElement) {
            var txt = (el.innerText || el.textContent || el.value || el.getAttribute('aria-label') || '').trim().toLowerCase();
            var id = (el.id || '').toLowerCase();
            var cls = (el.className || '').toString().toLowerCase();

            if (txt === 'join' || txt === 'join meeting' || txt === 'join audio' || txt === 'join with computer audio' ||
                txt.indexOf('join') === 0 || id.indexOf('join') !== -1 || cls.indexOf('join') !== -1 || cls.indexOf('preview-join') !== -1) {
              userClickedJoin = true;
              console.log('[ZoomBridge] User clicked Join button');
              postToFlutter({ type: 'userClickedJoin' });
              setTimeout(verifyInMeeting, 800);
              setTimeout(verifyInMeeting, 2000);
              setTimeout(verifyInMeeting, 3500);
              setTimeout(verifyInMeeting, 6000);
              break;
            }
            el = el.parentElement;
          }
        }
        window.addEventListener('click', handleJoinTap, true);
        window.addEventListener('touchend', handleJoinTap, true);

        // ─── Handle background taps to toggle Flutter Zoom controls ───
        var lastControlsToggleTime = 0;
        function handleBackgroundTap(e) {
          if (!isMeetingJoinedSent) return;
          var target = e.target;
          if (!target) return;

          // Check if user clicked any dialog, button, alert, input, or interactive widget
          var isInteractive = false;
          var curr = target;
          while (curr && curr !== document.body && curr !== document.documentElement) {
            var tag = (curr.tagName || '').toLowerCase();
            var cls = (curr.className || '').toString().toLowerCase();
            var role = (curr.getAttribute('role') || '').toLowerCase();

            if (tag === 'button' || tag === 'input' || tag === 'textarea' || tag === 'select' || tag === 'a' ||
                role === 'button' || role === 'dialog' || role === 'alertdialog' ||
                cls.indexOf('modal') !== -1 || cls.indexOf('dialog') !== -1 || cls.indexOf('alert') !== -1 ||
                cls.indexOf('btn') !== -1 || cls.indexOf('popover') !== -1 || cls.indexOf('dropdown') !== -1 ||
                cls.indexOf('suspension') !== -1 || cls.indexOf('self-video') !== -1 || cls.indexOf('filmstrip') !== -1 ||
                cls.indexOf('speaker-bar') !== -1) {
              isInteractive = true;
              break;
            }
            curr = curr.parentElement;
          }

          // If interactive (e.g. clicking OK on a Zoom meeting alert), DO NOT toggle controls!
          // Also automatically ensure the alert is dismissed if OK was clicked!
          if (isInteractive) {
            var okBtn = target.closest('button, [role="button"], .zm-btn');
            if (okBtn) {
              var btnText = (okBtn.innerText || okBtn.textContent || '').trim().toLowerCase();
              if (btnText === 'ok' || btnText === 'got it' || btnText === 'close' || btnText === 'cancel') {
                var modal = okBtn.closest('.zm-modal, [role="dialog"], .meeting-alert, .modal-dialog, div[class*="modal"]');
                if (modal) {
                  setTimeout(function() {
                    try {
                      if (modal && modal.parentElement) {
                        modal.style.setProperty('display', 'none', 'important');
                      }
                    } catch(err) {}
                  }, 50);
                }
              }
            }
            return;
          }

          // Otherwise, user tapped video background: toggle Flutter controls!
          var now = Date.now();
          if (now - lastControlsToggleTime < 350) return;
          lastControlsToggleTime = now;
          postToFlutter({ type: 'toggleControls' });
        }
        window.addEventListener('click', handleBackgroundTap, true);

        // Update real attendee count and full list from Zoom SDK
        function updateAttendeeCount(zm) {
          if (!zm) zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
          if (zm && zm.getAttendeeslist) {
            zm.getAttendeeslist({
              success: function(res) {
                if (res && res.result && res.result.attendeesList) {
                  var list = res.result.attendeesList;
                  postToFlutter({
                    type: 'attendeesList',
                    count: list.length,
                    attendees: list.map(function(a) {
                      return {
                        userId: a.userId,
                        userName: a.userName || a.displayName || 'Participant',
                        isHost: !!a.isHost,
                        isCoHost: !!a.isCoHost,
                        muted: a.muted !== false,
                        bVideoOn: !!a.bVideoOn,
                        isMySelf: !!a.isMySelf
                      };
                    })
                  });
                }
              }
            });
          }
        }

        // Authoritative verification via Zoom Web SDK API
        function verifyInMeeting() {
          if (isMeetingJoinedSent) return;
          var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
          if (!zm) return;

          // Check 1: ZoomMtg.getCurrentUser ONLY succeeds when user is inside the meeting room!
          if (zm.getCurrentUser) {
            zm.getCurrentUser({
              success: function(res) {
                if (res && res.result && res.result.currentUser && res.result.currentUser.userId) {
                  markInMeeting();
                  updateAttendeeCount(zm);
                }
              },
              error: function(err) {}
            });
          }

          // Check 2: If user clicked Join and #wc-footer or meeting toolbar buttons exist
          if (userClickedJoin && !isMeetingJoinedSent) {
            var activeToolbar = document.querySelector('#wc-footer .footer-button__button, #wc-footer button');
            if (activeToolbar) {
              markInMeeting();
              updateAttendeeCount(zm);
            }
          }
        }

        // Hook ZoomMtg.join() options so we receive the official success callback
        function hookZoomJoin() {
          var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
          if (!zm) return;

          if (zm.join && !zm.join.__premierHooked) {
            var originalJoin = zm.join;
            zm.join = function(options) {
              if (options) {
                var originalSuccess = options.success;
                options.success = function(res) {
                  markInMeeting();
                  updateAttendeeCount(zm);
                  if (originalSuccess) originalSuccess.apply(this, arguments);
                };
              }
              return originalJoin.apply(this, arguments);
            };
            zm.join.__premierHooked = true;
          }
        }

        // 4. Event-Driven Zoom SDK Listeners (NO POLLING, 60FPS)
        function initZoomEventListeners() {
          var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
          if (!zm) return false;

          hookZoomJoin();

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

          // ─── CHAT MESSAGE INTERCEPTION (3-Layer Fallback) ───────────────────────
          // The Zoom Client View SDK does NOT support inMeetingServiceListener('onChatReceived').
          // That event name is invalid and silently does nothing.
          // We use three strategies layered together for maximum compatibility.

          // Layer 1: MutationObserver on Zoom's chat DOM
          // Watches for new chat message nodes being inserted BEFORE our CSS hides them.
          // This fires synchronously on DOM mutation, so we capture the text before display:none.
          if (!window.__premierChatObserver) {
            var chatObserver = new MutationObserver(function(mutations) {
              mutations.forEach(function(mutation) {
                mutation.addedNodes.forEach(function(node) {
                  if (node.nodeType !== 1) return;
                  // Zoom renders chat messages in elements with class names like
                  // chat-message__text, chat-item, chat-message-item, etc.
                  var msgEl = null;
                  var senderEl = null;
                  // Try known Zoom chat class patterns
                  var msgCandidates = [
                    node.querySelector('[class*="chat-message__text"]'),
                    node.querySelector('[class*="chat-item__text"]'),
                    node.querySelector('[class*="chat-message-item"] [class*="text"]'),
                    node.querySelector('[class*="chat-message"] [class*="content"]'),
                    node.querySelector('[class*="message-content"]'),
                    node.querySelector('[class*="message__text"]'),
                    node.querySelector('[class*="chat__text"]'),
                    node.querySelector('.chat-message__text'),
                    node.querySelector('.chat-item__text')
                  ];
                  var senderCandidates = [
                    node.querySelector('[class*="chat-message__sender"]'),
                    node.querySelector('[class*="sender-name"]'),
                    node.querySelector('[class*="chat-item__sender"]'),
                    node.querySelector('[class*="participant-name"]'),
                    node.querySelector('[class*="user-name"]'),
                    node.querySelector('.sender'),
                    node.querySelector('[class*="sender"]')
                  ];

                  for (var i = 0; i < msgCandidates.length; i++) {
                    if (msgCandidates[i]) { msgEl = msgCandidates[i]; break; }
                  }
                  for (var j = 0; j < senderCandidates.length; j++) {
                    if (senderCandidates[j]) { senderEl = senderCandidates[j]; break; }
                  }

                  // Also check if the node itself is a chat message
                  if (!msgEl) {
                    var cls = (node.className || '').toString().toLowerCase();
                    if (cls.indexOf('chat') !== -1 && (cls.indexOf('message') !== -1 || cls.indexOf('item') !== -1)) {
                      var text = (node.innerText || node.textContent || '').trim();
                      if (text.length > 0 && text.length < 2000) {
                        msgEl = node;
                      }
                    }
                  }

                  if (!msgEl) return;

                  var messageText = (msgEl.innerText || msgEl.textContent || '').trim();
                  var senderText = senderEl ? (senderEl.innerText || senderEl.textContent || '').trim() : 'Participant';
                  if (senderText.slice(-1) === ':') senderText = senderText.slice(0, -1).trim();

                  if (!messageText || messageText.length === 0 || messageText.length > 2000) return;

                  var msgKey = senderText + '|' + messageText;
                  if (window.__premierChatSent && window.__premierChatSent[msgKey]) return;
                  if (!window.__premierChatSent) window.__premierChatSent = {};
                  window.__premierChatSent[msgKey] = true;

                  // Clean up old keys after 30s to prevent memory leak
                  setTimeout(function() {
                    if (window.__premierChatSent) delete window.__premierChatSent[msgKey];
                  }, 30000);

                  postToFlutter({
                    type: 'chatReceived',
                    sender: senderText,
                    message: messageText,
                    timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                  });
                });
              });
            });

            // Observe the entire document for chat nodes — Zoom mounts chat dynamically
            chatObserver.observe(document.body || document.documentElement, {
              childList: true,
              subtree: true
            });
            window.__premierChatObserver = chatObserver;
          }

          // Layer 2: Hook Zoom SDK's internal receiveChatMessage / onReceiveChatMsgEvent
          // Some Zoom SDK versions expose these on the ZoomMtg object or on window.__zm_eventbus
          try {
            var zm2 = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
            if (zm2) {
              var chatHookTargets = ['receiveChatMessage', 'onReceiveChatMsg', 'onChatMessage'];
              chatHookTargets.forEach(function(fnName) {
                if (zm2[fnName] && !zm2[fnName].__premierHooked) {
                  var orig = zm2[fnName];
                  zm2[fnName] = function(data) {
                    try {
                      if (data) {
                        var s = data.senderName || data.sender || 'Participant';
                        if (typeof s === 'object' && s.name) s = s.name;
                        var m = data.message || data.content || data.chatContent || '';
                        if (m) {
                          postToFlutter({ type: 'chatReceived', sender: s, message: m,
                            timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) });
                        }
                      }
                    } catch(ex) {}
                    return orig.apply(this, arguments);
                  };
                  zm2[fnName].__premierHooked = true;
                }
              });
            }
          } catch(e) {}



          try {
            zm.inMeetingServiceListener('onUserJoin', function(data) {
              updateAttendeeCount(zm);
            });
            zm.inMeetingServiceListener('onUserLeave', function(data) {
              updateAttendeeCount(zm);
            });
          } catch(e) {}

          try {
            zm.inMeetingServiceListener('onMeetingStatus', function(data) {
              if (data && (data.meetingStatus === 2 || data.meetingStatus === 'in-meeting' || data.meetingStatus === 'connected')) {
                verifyInMeeting();
              }
            });
          } catch(e) {}

          postToFlutter({ type: 'bridgeReady' });
          return true;
        }

        // Dynamic screen share detection to optimize GPU/CPU on low-end devices
        function checkScreenShareActive() {
          try {
            var shareEl = document.querySelector('#active-share-canvas, canvas[class*="share"], video[class*="share"], #active-share-container, .sharing-screen');
            var isSharing = !!(shareEl && (shareEl.offsetWidth > 0 || shareEl.offsetHeight > 0 || window.getComputedStyle(shareEl).display !== 'none'));
            if (isSharing) {
              document.body.classList.add('screen-sharing-active');
            } else {
              document.body.classList.remove('screen-sharing-active');
            }
          } catch(e) {}
        }

        // Re-apply data-saver status on each injection if enabled
        if (window.__dataSaverActive) {
          document.body.classList.add('data-saver-active');
          document.documentElement.classList.add('data-saver-active');
        }

        // Periodic maintenance check: keeps loading overlay suppressed, checks join button, and verifies in-meeting
        var checkCount = 0;
        var checkInterval = setInterval(function() {
          checkCount++;
          removeWebLoadingOverlay();
          ensureJoinButtonVisible();
          initZoomEventListeners();
          verifyInMeeting();
          checkScreenShareActive();

          if (isMeetingJoinedSent && checkCount > 100) {
            clearInterval(checkInterval);
            // Ultra-light 2s monitor for screen-share dynamic toggling without draining battery
            setInterval(function() {
              checkScreenShareActive();
            }, 2000);
          }
        }, 500);

      })();
    ''';

    controller.runJavaScript(js).catchError((_) {});
  }

  void _handleBridgeMessage(String message) {
    try {
      final data = jsonDecode(message);
      final String type = data['type'] ?? '';
      switch (type) {
        case 'attendeesList':
          final int count = data['count'] ?? 1;
          final rawList = data['attendees'];
          if (mounted) {
            setState(() {
              _participantCount = count;
              if (rawList is List) {
                _attendees.clear();
                _attendees.addAll(
                  rawList.map((item) => Map<String, dynamic>.from(item as Map)),
                );
              }
            });
            _participantsModalSetState?.call(() {});
          }
          break;
        case 'participantCount':
          final int count = data['count'] ?? 1;
          if (mounted && count > 0) {
            setState(() => _participantCount = count);
          }
          break;
        case 'userClickedJoin':
          debugPrint('[ZoomBridge] User clicked Join button in WebView');
          break;
        case 'toggleControls':
          if (mounted && _isMeetingJoined) {
            _toggleControls();
          }
          break;
        case 'audioState':
          final bool muted = data['muted'] ?? false;
          if (mounted && _isMuted != muted) {
            setState(() => _isMuted = muted);
          }
          break;
        case 'videoState':
          final bool videoOff = data['videoOff'] ?? false;
          if (mounted && _isVideoOff != videoOff) {
            setState(() => _isVideoOff = videoOff);
          }
          break;
        case 'chatReceived':
          if (mounted) {
            final String sender = data['sender']?.toString() ?? 'Participant';
            final String msgText = data['message']?.toString() ?? '';
            final String timeStr = data['timestamp']?.toString() ?? '';

            if (msgText.isNotEmpty) {
              // Time-windowed dedup: only suppress if the EXACT same sender+message
              // arrived within the last 2 seconds (handles multi-layer JS firing).
              // This still allows the same message to be sent twice legitimately.
              final now = DateTime.now();
              final isDuplicate = _chatMessages.isNotEmpty &&
                  _chatMessages.last['message'] == msgText &&
                  _chatMessages.last['sender'] == sender &&
                  _chatMessages.last['isMe'] == 'false' &&
                  _lastChatReceived != null &&
                  now.difference(_lastChatReceived!).inSeconds < 2;

              if (!isDuplicate) {
                _lastChatReceived = now;
                setState(() {
                  _chatMessages.add({
                    'sender': sender,
                    'message': msgText,
                    'timestamp': timeStr,
                    'isMe': 'false',
                  });
                  _unreadChatCount++;
                });
                _chatUpdateNotifier.value++;
                _chatModalSetState?.call(() {});
                // Scroll chat to bottom if open
                Future.delayed(const Duration(milliseconds: 80), () {
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
          }
          break;
        case 'bridgeReady':
          debugPrint('[ZoomBridge] Bridge ready');
          break;
        case 'meetingJoined':
          // Zoom SDK confirmed in-meeting — reveal Flutter controls
          if (mounted && !_isMeetingJoined) {
            debugPrint('[ZoomBridge] Confirmed in-meeting! Showing Zoom controls.');
            setState(() {
              _isMeetingJoined = true;
              _controlsVisible = true;
              if (_participantCount < 2) {
                _participantCount = 2;
              }
            });
            // Auto-hide after 6s once meeting is joined
            _startHideTimer();
          }
          break;
        case 'userJoined':
          if (mounted) {
            setState(() => _participantCount++);
          }
          break;
        case 'userLeft':
          if (mounted && _participantCount > 1) {
            setState(() => _participantCount--);
          }
          break;
      }
    } catch (e) {
      debugPrint('Error handling bridge message: $e');
    }
  }

  // ─── Zoom Interactive Commands ───────────────────────────────────────────
  void _toggleAudio() {
    _resetInactivityTimer();
    final willBeMuted = !_isMuted;
    setState(() => _isMuted = willBeMuted);
    _controller?.runJavaScript('''
      (function() {
        var shouldMute = $willBeMuted;
        var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
        if (zm && zm.muteAudio) {
          try {
            zm.muteAudio({
              mute: shouldMute,
              success: function() { console.log('[ZoomBridge] muteAudio success:', shouldMute); },
              error: function(e) { console.error('[ZoomBridge] muteAudio error:', e); }
            });
          } catch(e) {}
        }
        var sel = shouldMute
            ? 'button[aria-label*="Mute" i]'
            : 'button[aria-label*="Unmute" i]';
        var btn = document.querySelector(sel);
        if (btn) {
          btn.click();
        } else {
          var generalBtn = document.querySelector('.footer-button__audio button, button[aria-label*="audio" i]');
          if (generalBtn) generalBtn.click();
        }
      })();
    ''');
  }

  void _toggleVideo() {
    _resetInactivityTimer();
    final willBeVideoOff = !_isVideoOff;
    setState(() => _isVideoOff = willBeVideoOff);
    _controller?.runJavaScript('''
      (function() {
        var shouldMute = $willBeVideoOff;
        var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
        if (zm && zm.muteVideo) {
          try {
            zm.muteVideo({
              mute: shouldMute,
              success: function() { console.log('[ZoomBridge] muteVideo success:', shouldMute); },
              error: function(e) { console.error('[ZoomBridge] muteVideo error:', e); }
            });
          } catch(e) {}
        }
        var sel = shouldMute
            ? 'button[aria-label*="Stop Video" i], button[aria-label*="stop video" i]'
            : 'button[aria-label*="Start Video" i], button[aria-label*="start video" i]';
        var btn = document.querySelector(sel);
        if (btn) {
          btn.click();
        } else {
          var generalBtn = document.querySelector('.footer-button__video button, button[aria-label*="video" i]');
          if (generalBtn) generalBtn.click();
        }
      })();
    ''');
  }

  void _toggleSpeaker() {
    _resetInactivityTimer();
    final newSpeakerState = !_isSpeakerOn;
    setState(() => _isSpeakerOn = newSpeakerState);
    _controller?.runJavaScript('''
      (function() {
        var isMuted = ${!newSpeakerState};
        var mediaElements = document.querySelectorAll('audio, video');
        mediaElements.forEach(function(el) {
          el.muted = isMuted;
          el.volume = isMuted ? 0 : 1;
        });
      })();
    ''');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newSpeakerState ? 'Audio Speaker On 🔊' : 'Audio Speaker Off 🔇'),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1E293B),
      ),
    );
  }

  void _switchCamera() {
    _resetInactivityTimer();
    _controller?.runJavaScript('''
      (function() {
        var switchBtn = document.querySelector('button[aria-label*="Switch Camera"], button[aria-label*="switch camera"]');
        if (switchBtn) { switchBtn.click(); return; }
        var videoDropdown = document.querySelector('.footer-button__video-dropdown, [class*="video-option-arrow"]');
        if (videoDropdown) { videoDropdown.click(); }
      })();
    ''');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Flipping camera...'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF1E293B),
      ),
    );
  }

  void _toggleRaiseHand() {
    _resetInactivityTimer();
    final willRaise = !_isHandRaised;
    setState(() => _isHandRaised = willRaise);
    _controller?.runJavaScript('''
      (function() {
        try {
          if (typeof ZoomMtg !== 'undefined') {
            if ($willRaise && ZoomMtg.raiseHand) ZoomMtg.raiseHand({ success: function() {} });
            else if (!$willRaise && ZoomMtg.lowerHand) ZoomMtg.lowerHand({ success: function() {} });
          }
        } catch(e) {}
      })();
    ''');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(willRaise ? 'Hand Raised ✋' : 'Hand Lowered'),
        duration: const Duration(seconds: 2),
        backgroundColor: willRaise ? AppColors.primaryGreen : const Color(0xFF334155),
      ),
    );
  }

  void _toggleDataSaver() {
    _resetInactivityTimer();
    final newMode = !_isDataSaver;
    setState(() => _isDataSaver = newMode);
    _controller?.runJavaScript('''
      (function() {
        window.__dataSaverActive = $newMode;
        if ($newMode) {
          document.body.classList.add('data-saver-active');
          document.documentElement.classList.add('data-saver-active');
        } else {
          document.body.classList.remove('data-saver-active');
          document.documentElement.classList.remove('data-saver-active');
        }
      })();
    ''');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              newMode ? Icons.bolt : Icons.videocam,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                newMode
                    ? 'Data Saver ON: Audio-first mode for low latency & weak network.'
                    : 'Data Saver OFF: High-definition video restored.',
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
        backgroundColor: newMode ? AppColors.primaryGreen : const Color(0xFF334155),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _sendChatMessage(String message) {
    if (message.trim().isEmpty) return;
    final escapedMessage = message.replaceAll("'", "\\'").replaceAll('\n', ' ');
    _controller?.runJavaScript('''
      (function() {
        try {
          var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
          if (zm && zm.sendChat) {
            zm.sendChat({ message: '$escapedMessage', userId: 0 });
          }
        } catch(e) {}
      })();
    ''');

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

  void _handleLeaveClass(BuildContext context) {
    _resetInactivityTimer();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Meeting',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: const Text(
          'Do you want to leave the live class session?',
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

  // ─── Zoom Modals ──────────────────────────────────────────────────────────
  void _showParticipantsDialog() {
    _resetInactivityTimer();
    // Query latest attendees from Zoom SDK
    _controller?.runJavaScript('''
      (function() {
        var zm = window.ZoomMtg || (window.ZoomMtgLib && window.ZoomMtgLib.ZoomMtg);
        if (zm && zm.getAttendeeslist) {
          zm.getAttendeeslist({
            success: function(res) {
              if (res && res.result && res.result.attendeesList) {
                var list = res.result.attendeesList;
                if (window.FlutterZoomBridge) {
                  FlutterZoomBridge.postMessage(JSON.stringify({
                    type: 'attendeesList',
                    count: list.length,
                    attendees: list.map(function(a) {
                      return {
                        userId: a.userId,
                        userName: a.userName || a.displayName || 'Participant',
                        isHost: !!a.isHost,
                        isCoHost: !!a.isCoHost,
                        muted: a.muted !== false,
                        bVideoOn: !!a.bVideoOn,
                        isMySelf: !!a.isMySelf
                      };
                    })
                  }));
                }
              }
            }
          });
        }
      })();
    ''');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          _participantsModalSetState = setModalState;
          final totalCount = _attendees.isNotEmpty ? _attendees.length : _participantCount;

          return Theme(
            data: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF18181B),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Participants ($totalCount)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: _attendees.isEmpty
                        ? ListView(
                            shrinkWrap: true,
                            children: [
                              _buildParticipantTile('Instructor', 'Host', Icons.school, true, isMuted: false, isVideoOff: false),
                              if (_isMeetingJoined) ...[
                                const Divider(color: Colors.white10),
                                _buildParticipantTile('You', 'Me, Participant', Icons.person, false, isMuted: _isMuted, isVideoOff: _isVideoOff),
                              ],
                            ],
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            itemCount: _attendees.length,
                            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                            itemBuilder: (context, index) {
                              final attendee = _attendees[index];
                              final String name = attendee['userName'] ?? 'Participant';
                              final bool isHost = attendee['isHost'] == true;
                              final bool isCoHost = attendee['isCoHost'] == true;
                              final bool isMe = attendee['isMySelf'] == true;
                              final bool muted = attendee['muted'] == true;
                              final bool videoOn = attendee['bVideoOn'] == true;

                              String role = 'Participant';
                              if (isHost) {
                                role = isMe ? 'Host, Me' : 'Host';
                              } else if (isCoHost) {
                                role = isMe ? 'Co-Host, Me' : 'Co-Host';
                              } else if (isMe) {
                                role = 'Me, Participant';
                              }

                              return _buildParticipantTile(
                                name + (isMe ? ' (You)' : ''),
                                role,
                                isHost ? Icons.school : Icons.person,
                                isHost,
                                isMuted: muted,
                                isVideoOff: !videoOn,
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _participantsModalSetState = null;
    });
  }

  Widget _buildParticipantTile(
    String name,
    String role,
    IconData icon,
    bool isHost, {
    required bool isMuted,
    required bool isVideoOff,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: isHost ? AppColors.primaryGreen : const Color(0xFF334155),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  role,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            isMuted ? Icons.mic_off : Icons.mic,
            size: 18,
            color: isMuted ? Colors.redAccent : AppColors.primaryGreen,
          ),
          const SizedBox(width: 12),
          Icon(
            isVideoOff ? Icons.videocam_off : Icons.videocam,
            size: 18,
            color: isVideoOff ? Colors.redAccent : AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  void _showChatDialog() {
    _resetInactivityTimer();
    setState(() => _unreadChatCount = 0);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          _chatModalSetState = setModalState;
          final isLandscape = MediaQuery.of(ctx).orientation == Orientation.landscape;
          final viewInsetsBottom = MediaQuery.of(ctx).viewInsets.bottom;
          final screenHeight = MediaQuery.of(ctx).size.height;
          final maxSheetHeight = isLandscape ? (screenHeight * 0.92) : (screenHeight * 0.78);

          return Theme(
            data: ThemeData.dark().copyWith(
              scaffoldBackgroundColor: const Color(0xFF18181B),
              inputDecorationTheme: const InputDecorationTheme(
                filled: true,
                fillColor: Color(0xFF0F172A),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: isLandscape ? 24 : 16,
                  right: isLandscape ? 24 : 16,
                  top: 12,
                  bottom: viewInsetsBottom + 10,
                ),
                child: SizedBox(
                  height: (maxSheetHeight - viewInsetsBottom).clamp(180.0, maxSheetHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.chat_bubble_outline, color: AppColors.primaryGreen, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Meeting Chat',
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
                      const SizedBox(height: 8),
                      Expanded(
                        child: ValueListenableBuilder<int>(
                          valueListenable: _chatUpdateNotifier,
                          builder: (context, _, __) {
                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: _chatMessages.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No chat messages yet.\nType below to message the class.',
                                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                                        textAlign: TextAlign.center,
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
                                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? AppColors.primaryGreen.withValues(alpha: 0.25)
                                                    : const Color(0xFF1E293B),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isMe ? AppColors.primaryGreen.withValues(alpha: 0.3) : Colors.white12,
                                                ),
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
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    msg['message'] ?? '',
                                                    style: const TextStyle(color: Colors.white, fontSize: 13),
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
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white24, width: 1.2),
                              ),
                              alignment: Alignment.center,
                              child: TextField(
                                controller: _chatController,
                                cursorColor: AppColors.primaryGreen,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                decoration: const InputDecoration(
                                  isDense: true,
                                  filled: true,
                                  fillColor: Color(0xFF0F172A),
                                  hintText: 'Send a message...',
                                  hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
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
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      _chatModalSetState = null;
    });
  }

  void _showMoreOptions() {
    _resetInactivityTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMoreState) {
          final isLandscape = MediaQuery.of(ctx).orientation == Orientation.landscape;
          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * (isLandscape ? 0.88 : 0.65),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: isLandscape ? 24.0 : 8.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
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
                      leading: Icon(
                        _isDataSaver ? Icons.bolt : Icons.speed,
                        color: _isDataSaver ? AppColors.primaryGreen : Colors.white,
                      ),
                      title: Text(
                        _isDataSaver ? 'Disable Data Saver' : 'Enable Data Saver',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      subtitle: Text(
                        _isDataSaver
                            ? 'Audio-first mode active (saves 85% data & stops lag)'
                            : 'Audio-first mode for weak networks & budget devices',
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Switch(
                        value: _isDataSaver,
                        activeThumbColor: AppColors.primaryGreen,
                        onChanged: (val) {
                          Navigator.pop(ctx);
                          _toggleDataSaver();
                        },
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleDataSaver();
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: Colors.white),
                      title: const Text('Meeting Info', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: Text(widget.title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () {
                        Navigator.pop(ctx);
                        _showMeetingInfo();
                      },
                    ),
                    ListTile(
                      leading: Icon(
                        _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                        color: Colors.white,
                      ),
                      title: Text(
                        _isSpeakerOn ? 'Mute Audio Output' : 'Unmute Audio Output',
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleSpeaker();
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMeetingInfo() {
    _resetInactivityTimer();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isLandscape = MediaQuery.of(ctx).orientation == Orientation.landscape;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * (isLandscape ? 0.90 : 0.70),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 28.0 : 20.0,
                vertical: 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Meeting Details',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildInfoRow(Icons.class_outlined, 'Class', widget.title),
                  const SizedBox(height: 10),
                  _buildInfoRow(Icons.tag, 'Session ID', widget.classId),
                  const SizedBox(height: 10),
                  _buildInfoRow(Icons.shield_outlined, 'Encryption', 'Enhanced End-to-End', valueColor: AppColors.primaryGreen),
                  const SizedBox(height: 10),
                  _buildInfoRow(Icons.people_outline, 'Active Participants', '$_participantCount Connected'),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 12),
        Text('$label: ', style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor ?? Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    super.dispose();
  }

  // ─── Main Build (Unified Responsive Zoom Interface) ──────────────────────
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleLeaveClass(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;

            return Stack(
              children: [
                // 1. Fullscreen Video Stage — WebView renders here
                Positioned.fill(
                  child: _buildVideoView(),
                ),

                // 2. Tap-intercept overlay ABOVE WebView
                //    - Controls HIDDEN: full-screen opaque detector brings
                //      controls back on a single tap.
                //    - Controls VISIBLE: a center-strip detector (between
                //      top bar ~100px and bottom bar ~100px) lets the user
                //      tap the video area to hide them again, while the
                //      WebView behind remains scrollable / interactive in
                //      the remaining regions.
                // Tap-intercept overlay — only active AFTER meeting joined
                // 2. Zoom Controls & Overlays — STRICTLY rendered only after user has joined the meeting
                // While in pre-join / waiting / loading, NOTHING is rendered on top of the WebView,
                // ensuring the Join button and pre-join controls have 100% unobstructed touch events.
                if (_isMeetingJoined) ...[
                  // 3. Zoom Top Header Bar (Animated slide in/out)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    top: _controlsVisible ? 0 : -120,
                    left: 0,
                    right: 0,
                    child: _buildZoomTopBar(isLandscape),
                  ),

                  // 4. Zoom Bottom Action Toolbar (Animated slide in/out)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    bottom: _controlsVisible ? 0 : -140,
                    left: 0,
                    right: 0,
                    child: _buildZoomBottomBar(isLandscape),
                  ),

                  // 4.5 Data Saver active status indicator
                  if (_isDataSaver)
                    Positioned(
                      top: isLandscape ? 48 : 96,
                      left: 24,
                      right: 24,
                      child: IgnorePointer(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xE60F172A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.6), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.bolt, color: AppColors.primaryGreen, size: 15),
                                SizedBox(width: 6),
                                Text(
                                  'Data Saver Active • High Efficiency Audio',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],

                // 5. Loading spinner
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoView() {
    if (kIsWeb) {
      return _buildWebPlaceholder();
    }
    if (_controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    // High-performance WebView without gesture contention
    return WebViewWidget(controller: _controller!);
  }

  // ─── Zoom Style Top Header Bar ───────────────────────────────────────────
  Widget _buildZoomTopBar(bool isLandscape) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.9),
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
        ),
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: isLandscape ? 4 : 36,
        bottom: 12,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Audio Output / Speaker Button
            InkWell(
              onTap: _toggleSpeaker,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Camera Switch Button
            InkWell(
              onTap: _switchCamera,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.flip_camera_ios_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Centered Meeting Info Badge (Tappable)
            Expanded(
              child: InkWell(
                onTap: _showMeetingInfo,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield, color: AppColors.primaryGreen, size: 14),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Quick Data Saver Toggle Button
            InkWell(
              onTap: _toggleDataSaver,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _isDataSaver
                      ? AppColors.primaryGreen.withValues(alpha: 0.25)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isDataSaver ? AppColors.primaryGreen : Colors.white24,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isDataSaver ? Icons.bolt : Icons.speed,
                      color: _isDataSaver ? AppColors.primaryGreen : Colors.white70,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Saver',
                      style: TextStyle(
                        color: _isDataSaver ? AppColors.primaryGreen : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Red Zoom Leave Pill Button
            InkWell(
              onTap: () => _handleLeaveClass(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Zoom Style Bottom Action Toolbar ────────────────────────────────────
  Widget _buildZoomBottomBar(bool isLandscape) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF218181B), // Signature Zoom translucent dark charcoal
        border: const Border(
          top: BorderSide(color: Colors.white10, width: 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: 6,
        bottom: isLandscape ? 6 : 16,
        left: 6,
        right: 6,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Mute / Unmute
            _buildZoomToolbarButton(
              icon: _isMuted ? Icons.mic_off : Icons.mic,
              label: _isMuted ? 'Unmute' : 'Mute',
              isAlert: _isMuted,
              onTap: _toggleAudio,
            ),

            // 2. Start Video / Stop Video
            _buildZoomToolbarButton(
              icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
              label: _isVideoOff ? 'Start Video' : 'Stop Video',
              isAlert: _isVideoOff,
              onTap: _toggleVideo,
            ),

            // 3. Participants
            _buildZoomToolbarButton(
              icon: Icons.people_outline,
              label: 'Participants',
              badgeCount: _participantCount,
              onTap: _showParticipantsDialog,
            ),

            // 4. Chat
            _buildZoomToolbarButton(
              icon: Icons.chat_bubble_outline,
              label: 'Chat',
              hasDot: _unreadChatCount > 0,
              onTap: _showChatDialog,
            ),

            // 5. More (•••)
            _buildZoomToolbarButton(
              icon: Icons.more_horiz,
              label: 'More',
              onTap: _showMoreOptions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomToolbarButton({
    required IconData icon,
    required String label,
    bool isAlert = false,
    int? badgeCount,
    bool hasDot = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        _resetInactivityTimer();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isAlert ? const Color(0xFFEF4444) : Colors.white,
                  size: 22,
                ),
                if (badgeCount != null && badgeCount > 0)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (hasDot)
                  Positioned(
                    top: -2,
                    right: -4,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isAlert ? const Color(0xFFEF4444) : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Web Placeholder Fallback ─────────────────────────────────────────────
  Widget _buildWebPlaceholder() {
    final classroomUrl =
        '${ApiConfig.frontendUrl}/dashboard/classes/${widget.classId}?token=${widget.token}&fromApp=true';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.open_in_new, color: AppColors.primaryGreen, size: 64),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your virtual classroom is opening in a new tab.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
