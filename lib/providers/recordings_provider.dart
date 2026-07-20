import 'package:flutter/material.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/models/recording.dart';
import 'package:premier_lms/services/api_service.dart';

/// Manages recordings state — grouped by course, sorted by class number.
/// Mirrors the dashboard recordings tab logic.
class RecordingsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Recording> _allRecordings = [];
  bool _isLoading = false;
  String? _error;
  String? _playingId;

  List<Recording> get allRecordings => _allRecordings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get playingId => _playingId;

  /// Recordings grouped by course name.
  Map<String, List<Recording>> get recordingsByCourse {
    final map = <String, List<Recording>>{};
    for (final rec in _allRecordings) {
      map.putIfAbsent(rec.courseName, () => []).add(rec);
    }
    // Sort lectures within each course by classNo
    for (final list in map.values) {
      list.sort((a, b) {
        final numA = int.tryParse(a.classNo ?? '0') ?? 0;
        final numB = int.tryParse(b.classNo ?? '0') ?? 0;
        return numA.compareTo(numB);
      });
    }
    return map;
  }

  Future<void> loadRecordings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.dio.get(ApiConfig.classesMyRecordings);
      final data = response.data as List<dynamic>;
      _allRecordings = data
          .map((json) => Recording.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = 'Failed to load recordings';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Request a recording playback token.
  /// Returns the token on success, null on failure.
  Future<String?> getRecordingToken(String classId) async {
    _playingId = classId;
    notifyListeners();

    try {
      final response =
          await _api.dio.post(ApiConfig.recordingToken(classId));
      return response.data['token']?.toString();
    } catch (e) {
      return null;
    } finally {
      _playingId = null;
      notifyListeners();
    }
  }
}
