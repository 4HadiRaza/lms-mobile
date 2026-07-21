import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/services/api_service.dart';

class RecordingPlayerScreen extends StatefulWidget {
  final String token;

  const RecordingPlayerScreen({super.key, required this.token});

  @override
  State<RecordingPlayerScreen> createState() => _RecordingPlayerScreenState();
}

class _RecordingPlayerScreenState extends State<RecordingPlayerScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _error;
  
  String? _videoId;
  String? _courseName;
  late YoutubePlayerController _controller;
  bool _isFullScreen = false;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _verifyAndLoadVideo();
  }

  Future<void> _verifyAndLoadVideo() async {
    try {
      final response = await _api.dio.post(
        ApiConfig.recordingVerify,
        data: {'token': widget.token},
      );
      
      final data = response.data;
      if (data['type'] == 'youtube' && data['videoId'] != null) {
        _videoId = data['videoId'];
        _courseName = data['courseName'] ?? 'Recording';
        _initPlayer();
        
        final expiresIn = data['expiresInSeconds'] as int?;
        if (expiresIn != null && expiresIn > 0) {
          _startExpiryTimer(expiresIn);
        }
      } else {
        setState(() {
          _error = 'Invalid recording data received.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to verify recording token. It may have expired.';
        _isLoading = false;
      });
    }
  }

  void _startExpiryTimer(int seconds) {
    _expiryTimer?.cancel();
    _expiryTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      _showExpiryDialog();
    });
  }

  void _showExpiryDialog() {
    if (_isFullScreen) {
      setState(() {
        _isFullScreen = false;
      });
    }
    _controller.pauseVideo();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Access Expired'),
          content: const Text('Your viewing session for this recording has expired.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // pop dialog
                Navigator.of(this.context).pop(); // pop player
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _initPlayer() {
    _controller = YoutubePlayerController.fromVideoId(
      videoId: _videoId!,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: false, // We will use our custom fullscreen
        mute: false,
        loop: false,
        enableJavaScript: true,
        strictRelatedVideos: true, // rel=0
        origin: 'https://www.youtube.com',
        userAgent: 'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Mobile Safari/537.36',
      ),
    );
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    // Restore orientation and system UI settings on exit
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (!kIsWeb) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
    if (!_isLoading && _videoId != null) {
      _controller.close();
    }
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });

    if (_isFullScreen) {
      // Hide status bar and navigation bar (Immersive Mode)
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      // Auto-rotate mobile screen to landscape
      if (!kIsWeb) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } else {
      // Restore status bar and navigation bar
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      // Restore mobile screen to portrait
      if (!kIsWeb) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('Loading...', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxPlayerHeight = screenHeight * 0.55;
    final playerHeight = (screenWidth * 9 / 16).clamp(100.0, maxPlayerHeight);
    final playerWidth = playerHeight * 16 / 9;

    final playerWidget = _buildSecurePlayer();

    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(child: playerWidget),
              _buildCustomControls(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _courseName ?? 'Recording',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.black,
            height: playerHeight,
            child: Center(
              child: SizedBox(
                width: playerWidth,
                height: playerHeight,
                child: playerWidget,
              ),
            ),
          ),
          _buildCustomControls(),
          
          Expanded(
            child: Container(
              color: AppColors.bgLight,
              width: double.infinity,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recording Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This recording is securely sandboxed. You cannot open it externally.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        border: Border.all(color: Colors.amber.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
                              const SizedBox(width: 8),
                              Text(
                                'Private Video Issues?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber.shade900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'If this video shows a "Private Video" error:\n\n'
                            '1. Open a new tab in this same browser window, go to YouTube.com, and sign in to the Google account that has access (e.g. tayyabatiq300@gmail.com). Then refresh this app.\n\n'
                            '2. Recommended for LMS: Change the YouTube visibility from "Private" to "Unlisted" in YouTube Studio. This keeps the video hidden from public search but allows the app to load it without requiring a Google login.',
                            style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurePlayer() {
    return Listener(
      // Block right click / long press at the Flutter container level
      onPointerDown: (event) {
        if (event.buttons == 2) {
          // Right click detected (on platforms that support it)
          // Listener catches it before it bubbles, but iframes are tricky.
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          YoutubePlayer(
            controller: _controller,
            backgroundColor: Colors.black,
          ),
          
          // Layer 1: Invisible Shields (Visual Blocking)
          // Top-Left Blocker (Channel Avatar & Title)
          Positioned(
            top: 0,
            left: 0,
            width: 250,
            height: 70,
            child: PointerInterceptor(
              child: GestureDetector(
                onTap: () {},
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          // Top-Right Blocker (Share & Watch Later)
          Positioned(
            top: 0,
            right: 0,
            width: 150,
            height: 70,
            child: PointerInterceptor(
              child: GestureDetector(
                onTap: () {},
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          // Bottom-Right Blocker (YouTube Logo & External Link)
          Positioned(
            bottom: 0,
            right: 0,
            width: 120,
            height: 60,
            child: PointerInterceptor(
              child: GestureDetector(
                onTap: () {},
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomControls() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
              color: Colors.white,
            ),
            onPressed: _toggleFullScreen,
            tooltip: _isFullScreen ? 'Exit Full Screen' : 'Full Screen',
          ),
        ],
      ),
    );
  }
}
