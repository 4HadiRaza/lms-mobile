import 'package:flutter/foundation.dart';

/// Central API configuration matching the backend endpoints
/// used by the Next.js frontend.
class ApiConfig {
  // Production URL
  static const String _prodUrl = 'https://premier-l-ms-backend-lhy5.vercel.app/api';

  // Local Development URLs
  // For Flutter Web and iOS Simulator: http://localhost:3001/api
  // For Android Emulator: http://10.0.2.2:3001/api
  static const String _localUrlWebAndIos = 'http://localhost:3001/api';
  static const String _localUrlAndroid = 'http://10.0.2.2:3001/api';

  // Set this to true to force production URL even in debug mode, or false to use local backend.
  static const bool useProdInDebug = true;

  static String get baseUrl {
    if (!kDebugMode || useProdInDebug) {
      return _prodUrl;
    }
    
    if (kIsWeb) {
      return _localUrlWebAndIos;
    }
    
    // In debug mode, automatically detect platform for local testing
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _localUrlAndroid;
    }
    return _localUrlWebAndIos;
  }

  static String get frontendUrl {
    if (!kDebugMode || useProdInDebug) {
      return 'https://premier-lms-frontend.vercel.app';
    }
    
    if (kIsWeb) {
      return 'http://localhost:3000';
    }
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }


  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String profile = '/auth/profile';
  static const String logout = '/auth/logout';
  static const String changePassword = '/auth/change-password';

  // Courses
  static const String courses = '/courses';
  static const String coursesAll = '/courses/all';

  // Batches
  static const String batchesPublic = '/batches/public';

  // Classes
  static const String classesPublicUpcoming = '/classes/public/upcoming';
  static const String classesMyUpcoming = '/classes/my/upcoming';
  static const String classesMyPast = '/classes/my/past';
  static const String classesMyRecordings = '/classes/my/recordings';
  static const String classesCountUpcoming = '/classes/count/upcoming';
  static String joinClass(String id) => '/classes/$id/join';

  /// POST /classes/:id/recording-token
  static String recordingToken(String id) => '/classes/$id/recording-token';
  static const String recordingVerify = '/classes/recording/verify';

  // Admissions
  static const String admissions = '/admissions';

  // Uploads
  static const String uploads = '/uploads';

  // Admin
  static const String users = '/users';

  /// Constructs a full media URL for thumbnails stored on the backend.
  static String mediaUrl(String? path) {
    if (path == null || path.isEmpty) {
      return 'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=600&h=340&fit=crop';
    }
    if (path.startsWith('http')) return path;
    final cleanPath = path.replaceFirst(RegExp(r'^\.?/'), '');
    return '$baseUrl/uploads/$cleanPath';
  }
}
