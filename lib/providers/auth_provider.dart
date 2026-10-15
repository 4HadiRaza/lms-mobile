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
    } on DioException catch (e) {
      _error = _parseDioError(e, fallback: 'Invalid email or password.');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Login error: $e';
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
      _error = _parseDioError(e, fallback: 'Signup failed. Please try again.');
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

  String _parseDioError(DioException e, {required String fallback}) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Please check your internet connection and try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Unable to reach server. Please check your internet connection.';
    }

    final responseData = e.response?.data;
    var backendMsg = responseData is Map ? responseData['message'] : null;
    if (backendMsg is List) backendMsg = backendMsg.join(', ');

    var detailedErrors = '';
    if (responseData is Map && responseData['errors'] != null) {
      if (responseData['errors'] is Map) {
        final joined = (responseData['errors'] as Map)
            .values
            .map((v) => v is List ? v.join(', ') : v)
            .join(' | ');
        detailedErrors = ': $joined';
      } else if (responseData['errors'] is List) {
        final joined = (responseData['errors'] as List).join(', ');
        detailedErrors = ': $joined';
      }
    }

    if (backendMsg != null && backendMsg.toString().isNotEmpty) {
      return '$backendMsg$detailedErrors';
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      return 'Invalid email or password.';
    } else if (statusCode == 403) {
      return 'Account access restricted. Please contact support.';
    } else if (statusCode != null && statusCode >= 500) {
      return 'Server error ($statusCode). Please try again shortly.';
    }

    return fallback;
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
