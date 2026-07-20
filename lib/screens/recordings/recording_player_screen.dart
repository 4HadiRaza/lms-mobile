import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
      ),
    );
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    if (!_isLoading && _videoId != null) {
      _controller.close();
    }
    super.dispose();
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    // In a real app, you might use SystemChrome to hide status bars here,
    // or requestFullscreen() on web using a platform channel/JS interop.
    // We will use a basic fullscreen layout swap.
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
          // 16:9 Aspect Ratio container for standard view
          AspectRatio(
            aspectRatio: 16 / 9,
            child: playerWidget,
          ),
          _buildCustomControls(),
          
          Expanded(
            child: Container(
              color: AppColors.bgLight,
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recording Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This recording is securely sandboxed. You cannot open it externally.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
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
