import 'package:flutter/material.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/models/course.dart';
import 'package:premier_lms/services/api_service.dart';

/// Manages course catalog state with filtering — mirrors courses/page.tsx logic.
class CoursesProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  List<Course> _allCourses = [];
  bool _isLoading = false;
  String? _error;

  // Filters
  String _search = '';
  List<String> _selectedCategories = [];
  List<String> _selectedLevels = [];
  String _priceFilter = 'all'; // 'all', 'free', 'paid'
  String _sort = 'popular';

  // Getters
  List<Course> get allCourses => _allCourses;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get search => _search;
  List<String> get selectedCategories => _selectedCategories;
  List<String> get selectedLevels => _selectedLevels;
  String get priceFilter => _priceFilter;
  String get sort => _sort;

  static const List<String> categories = [
    'Income Tax',
    'Sales Tax & GST',
    'Corporate Accounting',
    'FBR Compliance',
    'Bookkeeping',
    'Audit & Assurance',
  ];

  static const List<String> levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  /// Filtered and sorted courses.
  List<Course> get filteredCourses {
    var result = List<Course>.from(_allCourses);

    // Search
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      result = result.where((c) {
        return c.title.toLowerCase().contains(q) ||
            c.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    // Category
    if (_selectedCategories.isNotEmpty) {
      result =
          result.where((c) => _selectedCategories.contains(c.category)).toList();
    }

    // Level
    if (_selectedLevels.isNotEmpty) {
      result =
          result.where((c) => _selectedLevels.contains(c.level)).toList();
    }

    // Price
    if (_priceFilter == 'free') {
      result = result.where((c) => c.isFree).toList();
    } else if (_priceFilter == 'paid') {
      result = result.where((c) => !c.isFree).toList();
    }

    // Sort
    switch (_sort) {
      case 'popular':
        result.sort((a, b) => b.enrollmentCount.compareTo(a.enrollmentCount));
        break;
      case 'newest':
        result.sort((a, b) => b.id.compareTo(a.id));
        break;
      case 'price-asc':
        result.sort(
            (a, b) => (a.price ?? 0).compareTo(b.price ?? 0));
        break;
      case 'price-desc':
        result.sort(
            (a, b) => (b.price ?? 0).compareTo(a.price ?? 0));
        break;
    }

    return result;
  }

  bool get hasActiveFilters =>
      _search.isNotEmpty ||
      _selectedCategories.isNotEmpty ||
      _selectedLevels.isNotEmpty ||
      _priceFilter != 'all';

  Future<void> loadCourses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.dio.get(ApiConfig.courses);
      final data = response.data as List<dynamic>;
      _allCourses = data
          .map((json) => Course.fromApiJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
      _allCourses = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void setSearch(String value) {
    _search = value;
    notifyListeners();
  }

  void toggleCategory(String category) {
    if (_selectedCategories.contains(category)) {
      _selectedCategories.remove(category);
    } else {
      _selectedCategories.add(category);
    }
    notifyListeners();
  }

  void toggleLevel(String level) {
    if (_selectedLevels.contains(level)) {
      _selectedLevels.remove(level);
    } else {
      _selectedLevels.add(level);
    }
    notifyListeners();
  }

  void setPriceFilter(String filter) {
    _priceFilter = filter;
    notifyListeners();
  }

  void setSort(String sort) {
    _sort = sort;
    notifyListeners();
  }

  void clearFilters() {
    _search = '';
    _selectedCategories = [];
    _selectedLevels = [];
    _priceFilter = 'all';
    _sort = 'popular';
    notifyListeners();
  }

  /// Get a single course by slug.
  Course? getCourseBySlug(String slug) {
    try {
      return _allCourses.firstWhere((c) => c.slug == slug);
    } catch (_) {
      return null;
    }
  }
}
