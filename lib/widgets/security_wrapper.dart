import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:screen_protector/screen_protector.dart';

class SecurityWrapper extends StatefulWidget {
  final Widget child;

  const SecurityWrapper({super.key, required this.child});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> {
  final bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initScreenProtection();
  }

  Future<void> _initScreenProtection() async {
    // Temporarily disabled for error reporting and screenshot capture
  }



  @override
  void dispose() {
    if (!kIsWeb) {
      if (Platform.isIOS) {
        ScreenProtector.removeListener();
      }
      ScreenProtector.preventScreenshotOff();
      if (Platform.isAndroid) {
        ScreenProtector.protectDataLeakageOff();
      } else if (Platform.isIOS) {
        ScreenProtector.protectDataLeakageWithBlurOff();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
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
                      Icon(Icons.security, color: Colors.white, size: 64),
                      SizedBox(height: 24),
                      Text(
                        'Screen Recording Detected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'For security reasons, the content of this application is hidden while screen recording is active.',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
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
