import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/models/live_class.dart';
import 'package:premier_lms/services/api_service.dart';

/// Manages live classes state — upcoming (public + student) and past.
class ClassesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<LiveClass> _publicUpcoming = [];
  List<LiveClass> _myUpcoming = [];
  List<LiveClass> _myPast = [];
  bool _isLoading = false;
  String? _error;

  List<LiveClass> get publicUpcoming => _publicUpcoming;
  List<LiveClass> get myUpcoming => _myUpcoming;
  List<LiveClass> get myPast => _myPast;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Load public upcoming classes (for home page).
  Future<void> loadPublicUpcoming() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.dio.get(ApiConfig.classesPublicUpcoming);
      final data = response.data as List<dynamic>;
      _publicUpcoming = data
          .map((json) =>
              LiveClass.fromPublicJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load upcoming classes';
      _publicUpcoming = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load student's upcoming and past classes (for dashboard).
  Future<void> loadStudentClasses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.dio.get(ApiConfig.classesMyUpcoming),
        _api.dio.get(ApiConfig.classesMyPast),
      ]);

      _myUpcoming = (results[0].data as List<dynamic>)
          .map((json) =>
              LiveClass.fromStudentJson(json as Map<String, dynamic>))
          .toList();

      _myPast = (results[1].data as List<dynamic>)
          .map((json) =>
              LiveClass.fromStudentJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load your classes';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get the zoom meeting join URL
  Future<String?> getJoinUrl(String classId) async {
    try {
      final response = await _api.dio.get(ApiConfig.joinClass(classId));
      final data = response.data;
      final meetingId = data['zoomMeetingId']?.toString();
      final passcode = data['zoomPasscode']?.toString();
      
      if (meetingId != null) {
        if (passcode != null && passcode.isNotEmpty) {
          return 'https://zoom.us/j/$meetingId?pwd=$passcode';
        }
        return 'https://zoom.us/j/$meetingId';
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
