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

    final user = User.fromJson(
      profile is Map<String, dynamic>
          ? profile
          : Map<String, dynamic>.from(profile as Map),
    );

    await _api.saveUser(jsonEncode(user.toJson()));
    return user;
  }

  /// Register a new account.
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _api.dio.post(
      ApiConfig.register,
      data: {'name': name.trim(), 'email': email.trim(), 'password': password},
    );

    final data = response.data;
    final accessToken = data['accessToken'] as String;
    await _api.saveToken(accessToken);

    // Fetch full profile with enrollments
    try {
      final profileRes = await _api.dio.get(ApiConfig.profile);
      final profile = profileRes.data;
      final user = User.fromJson(
        profile is Map<String, dynamic>
            ? profile
            : Map<String, dynamic>.from(profile as Map),
      );
      await _api.saveUser(jsonEncode(user.toJson()));
      return user;
    } catch (_) {
      final userData = data['user'] is Map<String, dynamic>
          ? data['user'] as Map<String, dynamic>
          : Map<String, dynamic>.from(data['user'] as Map);
      final user = User.fromJson(userData);
      await _api.saveUser(jsonEncode(user.toJson()));
      return user;
    }
  }

  /// Register a new account, then auto-login (legacy alias).
  Future<User> signup(String name, String email, String password) async {
    return register(name: name, email: email, password: password);
  }

  /// Delete account permanently (Apple Guideline 5.1.1(v)).
  Future<void> deleteAccount() async {
    try {
      await _api.dio.delete(ApiConfig.deleteAccount);
    } finally {
      await _api.clearAuth();
    }
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
    String currentPassword,
    String newPassword,
  ) async {
    await _api.dio.post(
      ApiConfig.changePassword,
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  /// Request a password reset email.
  /// Sends the email to the backend; the backend sends a reset link.
  Future<void> forgotPassword(String email) async {
    await _api.dio.post(ApiConfig.forgotPassword, data: {'email': email});
  }

  /// Reset password using the token received via email.
  Future<void> resetPassword(String token, String newPassword) async {
    await _api.dio.post(
      ApiConfig.resetPassword,
      data: {'token': token, 'newPassword': newPassword},
    );
  }
}
