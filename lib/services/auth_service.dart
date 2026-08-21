import 'dart:convert';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/models/user.dart';
import 'package:premier_lms/services/api_service.dart';

/// Authentication service mirroring AuthContext.tsx logic.
class AuthService {
  final ApiService _api = ApiService();

  /// Login with email and password.
  /// Returns the User on success, throws on failure.
  Future<User> login(String email, String password) async {
    final response = await _api.dio.post(
      ApiConfig.login,
      data: {'email': email, 'password': password},
    );

    final data = response.data;
    final accessToken = data['accessToken'] as String;
    await _api.saveToken(accessToken);

    // Fetch full profile with enrollments
    final profileRes = await _api.dio.get(ApiConfig.profile);
    final profile = profileRes.data;

    final user = User.fromJson(profile is Map<String, dynamic>
        ? profile
        : Map<String, dynamic>.from(profile as Map));

    await _api.saveUser(jsonEncode(user.toJson()));
    return user;
  }

  /// Register a new account, then auto-login.
  Future<User> signup(String name, String email, String password) async {
    await _api.dio.post(
      ApiConfig.register,
      data: {'name': name, 'email': email, 'password': password},
    );
    return login(email, password);
  }

  /// Logout — calls server then clears local storage.
  Future<void> logout() async {
    try {
      await _api.dio.post(ApiConfig.logout);
    } catch (_) {
      // Ignore logout failure
    }
    await _api.clearAuth();
  }

  /// Restore session from secure storage.
  Future<User?> restoreSession() async {
    final token = await _api.getToken();
    final storedUser = await _api.getSavedUser();

    if (token == null || storedUser == null) return null;

    try {
      final parsed = jsonDecode(storedUser);
      User user = User.fromJson(parsed);

      // Sync with server
      final profileRes = await _api.dio.get(ApiConfig.profile);
      user = User.fromJson(profileRes.data);
      await _api.saveUser(jsonEncode(user.toJson()));

      return user;
    } catch (_) {
      await _api.clearAuth();
      return null;
    }
  }

  /// Change password — logs out on success.
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await _api.dio.post(
      ApiConfig.changePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }
}
