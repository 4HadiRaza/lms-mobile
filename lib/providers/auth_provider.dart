import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:premier_lms/models/user.dart';
import 'package:premier_lms/services/api_service.dart';
import 'package:premier_lms/services/auth_service.dart';

/// Auth state provider mirroring AuthContext.tsx.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  User? _user;
  bool _isLoading = true;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get error => _error;

  AuthProvider() {
    // Wire up session expiry callback
    ApiService().onSessionExpired = () {
      _user = null;
      notifyListeners();
    };
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.restoreSession();
    } catch (_) {
      _user = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.login(email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Login failed. Please check your credentials.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.signup(name, email, password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on DioException catch (e) {
      var backendMsg = e.response?.data?['message'];
      if (backendMsg is List) backendMsg = backendMsg.join(', ');
      _error = backendMsg ?? 'Network error: ${e.message}';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _error = null;
    notifyListeners();
  }

  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      await _authService.changePassword(currentPassword, newPassword);
      return true;
    } catch (e) {
      _error = 'Failed to change password.';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
