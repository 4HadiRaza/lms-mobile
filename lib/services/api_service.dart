import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:premier_lms/config/api_config.dart';

/// Dio-based HTTP client mirroring the Axios setup in api.ts.
/// Handles JWT attachment and 401 auto-logout.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;
  String? _cachedToken;

  /// Callback invoked on 401 session expiry — set by AuthProvider.
  void Function()? onSessionExpired;

  ApiService._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // Attach JWT token to every request
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = _cachedToken ?? await getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final message =
              error.response?.data?['message']?.toString() ?? '';
          if (message.contains('Session expired') ||
              message.contains('logged in from another device')) {
            await clearAuth();
            onSessionExpired?.call();
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<void> saveToken(String token) async {
    _cachedToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessToken', token);
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('accessToken');
    return _cachedToken;
  }

  Future<void> clearAuth() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('user');
  }

  Future<void> saveUser(String userJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', userJson);
  }

  Future<String?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user');
  }
}
