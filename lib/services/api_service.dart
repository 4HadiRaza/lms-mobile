import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:flutter/foundation.dart';

/// Dio-based HTTP client with enterprise-grade secure token storage
/// using Android Keystore and iOS Keychain via FlutterSecureStorage.
/// Includes automatic migration from plaintext SharedPreferences.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late final Dio dio;
  String? _cachedToken;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

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
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        debugPrint('ApiService.onError: statusCode = ${error.response?.statusCode}, path = ${error.requestOptions.path}');
        if (error.response?.statusCode == 401) {
          String message = '';
          if (error.response?.data is Map) {
            message =
                (error.response!.data as Map)['message']?.toString() ?? '';
          }
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

  /// Securely saves access token in Android Keystore / iOS Keychain
  Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _secureStorage.write(key: 'accessToken', value: token);
    
    // Clean up any legacy plaintext copy
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('accessToken')) {
        await prefs.remove('accessToken');
      }
    } catch (_) {}
  }

  /// Retrieves token from Secure Storage with seamless migration from legacy SharedPreferences
  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;

    // 1. Try reading from hardware-backed secure storage
    try {
      final secureToken = await _secureStorage.read(key: 'accessToken');
      if (secureToken != null && secureToken.isNotEmpty) {
        _cachedToken = secureToken;
        return _cachedToken;
      }
    } catch (e) {
      debugPrint('SecureStorage read error: $e');
    }

    // 2. Migration Path: Check legacy SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyToken = prefs.getString('accessToken');
      if (legacyToken != null && legacyToken.isNotEmpty) {
        // Migrate to secure storage
        await _secureStorage.write(key: 'accessToken', value: legacyToken);
        await prefs.remove('accessToken');
        _cachedToken = legacyToken;
        return _cachedToken;
      }
    } catch (e) {
      debugPrint('Legacy token migration error: $e');
    }

    return null;
  }

  /// Clears tokens and session data from secure storage and legacy preferences
  Future<void> clearAuth() async {
    _cachedToken = null;
    try {
      await _secureStorage.delete(key: 'accessToken');
      await _secureStorage.delete(key: 'user');
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('accessToken');
      await prefs.remove('user');
    } catch (_) {}
  }

  /// Securely saves user session JSON
  Future<void> saveUser(String userJson) async {
    await _secureStorage.write(key: 'user', value: userJson);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('user')) {
        await prefs.remove('user');
      }
    } catch (_) {}
  }

  /// Retrieves user session JSON from secure storage with legacy migration
  Future<String?> getSavedUser() async {
    try {
      final secureUser = await _secureStorage.read(key: 'user');
      if (secureUser != null && secureUser.isNotEmpty) {
        return secureUser;
      }
    } catch (_) {}

    // Legacy migration check for user profile
    try {
      final prefs = await SharedPreferences.getInstance();
      final legacyUser = prefs.getString('user');
      if (legacyUser != null && legacyUser.isNotEmpty) {
        await _secureStorage.write(key: 'user', value: legacyUser);
        await prefs.remove('user');
        return legacyUser;
      }
    } catch (_) {}

    return null;
  }
}
