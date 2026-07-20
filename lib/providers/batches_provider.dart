import 'package:flutter/material.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/models/batch.dart';
import 'package:premier_lms/services/api_service.dart';

/// Manages public batch data — upcoming vs active/past.
class BatchesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Batch> _allBatches = [];
  bool _isLoading = false;
  String? _error;

  List<Batch> get allBatches => _allBatches;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Batch> get upcomingBatches =>
      _allBatches.where((b) => b.isUpcoming).toList();

  List<Batch> get activePastBatches =>
      _allBatches.where((b) => b.isPastOrActive).toList();

  Future<void> loadBatches() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.dio.get(ApiConfig.batchesPublic);
      final data = response.data as List<dynamic>;
      _allBatches = data
          .map((json) => Batch.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
      _allBatches = [];
    }

    _isLoading = false;
    notifyListeners();
  }
}
