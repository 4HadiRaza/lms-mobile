import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:premier_lms/providers/auth_provider.dart';

/// Wraps the application with native & cross-platform security protections:
/// - Android: Hardware FLAG_SECURE prevents screenshots, recordings, and hides app preview in task switcher.
/// - iOS: Detects screenshots and active screen recording, displaying a privacy/blur overlay.
/// - Web / Cross-platform: Dynamic student email watermark and recording detection overlay.
class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScreenProtection();
  }

  Future<void> _initScreenProtection() async {
    if (kIsWeb) return;

    try {
      // 1. Enable Hardware / OS Screenshot Prevention
      await ScreenProtector.preventScreenshotOn();

      // 2. Prevent data leakage when switching apps / recent tasks preview
      if (Platform.isAndroid) {
        await ScreenProtector.protectDataLeakageWithColor(Colors.black);
      } else if (Platform.isIOS) {
        await ScreenProtector.protectDataLeakageWithBlur();
      }

      // 3. Check initial screen recording status on iOS/Android
      final isRecording = await ScreenProtector.isRecording();
      if (mounted && isRecording != _isRecording) {
        setState(() => _isRecording = isRecording);
      }

      // 4. Register listener for screenshots & screen recording state changes
      ScreenProtector.addListener(
        () async {
          // Triggered on iOS when screen recording status changes
          final recording = await ScreenProtector.isRecording();
          if (mounted) {
            setState(() => _isRecording = recording);
          }
        },
        (bool isScreenshot) {
          // Triggered on iOS when user takes a screenshot
          if (mounted && isScreenshot) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Warning: Capturing screenshots of Premier LMS course material is strictly prohibited.',
                ),
                backgroundColor: Color(0xFFDC2626),
                duration: Duration(seconds: 4),
              ),
            );
          }
        },
      );
    } catch (e) {
      debugPrint('ScreenProtector init error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      // Re-verify screen recording status on app resume
      ScreenProtector.isRecording().then((isRecording) {
        if (mounted && isRecording != _isRecording) {
          setState(() => _isRecording = isRecording);
        }
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!kIsWeb) {
      try {
        ScreenProtector.removeListener();
        ScreenProtector.preventScreenshotOff();
        if (Platform.isAndroid) {
          ScreenProtector.protectDataLeakageOff();
        } else if (Platform.isIOS) {
          ScreenProtector.protectDataLeakageWithBlurOff();
        }
      } catch (_) {}
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Stack(
      children: [
        // App Content
        widget.child,

        // Anti-piracy dynamic watermark for authenticated sessions
        if (user != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: _WatermarkPainter(
                    text: '${user.email} • Premier LMS',
                  ),
                ),
              ),
            ),
          ),

        // Screen Recording Blocking Overlay
        if (_isRecording)
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.white, size: 64),
                      SizedBox(height: 24),
                      Text(
                        'Screen Recording Detected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'For intellectual property and security compliance, course materials and live lectures are hidden while screen recording is active.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          height: 1.5,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Draws subtle repeating diagonal watermarks across the screen
class _WatermarkPainter extends CustomPainter {
  final String text;

  _WatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    canvas.save();
    canvas.rotate(-0.35); // Approx -20 degrees

    const stepX = 220.0;
    const stepY = 160.0;

    for (double x = -size.width; x < size.width * 2; x += stepX) {
      for (double y = -size.height; y < size.height * 2; y += stepY) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WatermarkPainter oldDelegate) =>
      oldDelegate.text != text;
}
