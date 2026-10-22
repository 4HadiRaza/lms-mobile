import 'dart:async';
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
  bool _isRevalidating = false;
  String? _error;

  /// Completes once the initial session restore attempt finishes.
  /// Await this before making routing decisions.
  final Completer<void> _sessionRestoreCompleter = Completer<void>();
  Future<void> get sessionRestored => _sessionRestoreCompleter.future;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  String? get error => _error;

  /// Whether a background re-validation is in progress (used for UI feedback).
  bool get isRevalidating => _isRevalidating;

  AuthProvider() {
    // Wire up session expiry callback on the singleton instance
    ApiService.instance.onSessionExpired = () {
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
    // Signal that the initial restore is done so the splash screen can route.
    if (!_sessionRestoreCompleter.isCompleted) {
      _sessionRestoreCompleter.complete();
    }
    notifyListeners();
  }

  /// Silently re-validates the stored token against the server.
  /// Called on app resume. Does NOT show a loading indicator to the user.
  /// If the token is invalid/expired, logs out and routes to login.
  Future<void> revalidateSession() async {
    if (_isRevalidating || _isLoading) return;
    if (_user == null) return; // Already logged out, nothing to revalidate.

    _isRevalidating = true;
    // No notifyListeners() here — we don't want to flash a spinner on resume.

    try {
      final freshUser = await _authService.restoreSession();
      if (freshUser == null) {
        // Token rejected by server — clear local state.
        _user = null;
        notifyListeners();
      } else {
        // Update user in case profile changed while away.
        _user = freshUser;
        notifyListeners();
      }
    } catch (_) {
      // Network unavailable — don't log out, let the user keep their session.
      // They'll get an error when they try to do something that needs the network.
    } finally {
      _isRevalidating = false;
    }
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
