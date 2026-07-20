/// Central API configuration matching the backend endpoints
/// used by the Next.js frontend.
class ApiConfig {
  // Change this to your backend URL
  static const String baseUrl = 'https://premier-lms.vercel.app/api';

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
