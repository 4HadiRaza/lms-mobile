import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:premier_lms/config/api_config.dart';
import 'package:premier_lms/models/course.dart';
import 'package:premier_lms/providers/auth_provider.dart';
import 'package:premier_lms/providers/courses_provider.dart';
import 'package:premier_lms/services/api_service.dart';

/// Provider managing the Apple StoreKit In-App Purchase lifecycle for iOS.
class IapProvider extends ChangeNotifier {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  AuthProvider? _authProvider;
  List<Course> _lastCourses = [];

  bool _isAvailable = false;
  bool _isLoadingProducts = false;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  int _restoredCount = 0;
  String? _purchasingCourseId;
  String? _errorMessage;
  String? _successMessage;

  final Map<String, ProductDetails> _products = {};
  final Map<String, String> _productIdToCourseId = {};

  bool get isAvailable => _isAvailable;
  bool get isLoadingProducts => _isLoadingProducts;
  bool get isPurchasing => _isPurchasing;
  bool get isRestoring => _isRestoring;
  String? get purchasingCourseId => _purchasingCourseId;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  Map<String, ProductDetails> get products => _products;

  IapProvider() {
    _initialize();
  }

  /// Called by ChangeNotifierProxyProvider2 whenever AuthProvider or CoursesProvider updates.
  void update(AuthProvider auth, CoursesProvider courses) {
    _authProvider = auth;

    if (courses.allCourses.isNotEmpty && courses.allCourses != _lastCourses) {
      _lastCourses = courses.allCourses;
      loadProducts(courses.allCourses);
    }
  }

  /// Platform guard and stream subscription.
  Future<void> _initialize() async {
    if (kIsWeb || !Platform.isIOS) {
      _isAvailable = false;
      return;
    }

    try {
      _isAvailable = await _iap.isAvailable();
      if (_isAvailable) {
        _subscription = _iap.purchaseStream.listen(
          _onPurchaseUpdate,
          onDone: () {
            _subscription?.cancel();
          },
          onError: (error) {
            debugPrint('IapProvider: purchaseStream error: $error');
            _errorMessage = error.toString();
            notifyListeners();
          },
        );
      }
    } catch (e) {
      debugPrint('IapProvider: initialization error: $e');
      _isAvailable = false;
    }
  }

  /// Resolves the Apple Product ID for a course (configured or fallback schema).
  String resolveAppleProductId(Course course) {
    if (course.appleProductId != null &&
        course.appleProductId!.trim().isNotEmpty) {
      return course.appleProductId!.trim();
    }
    // Fallback mapping for our primary course: Mastering Income Tax Ordinances 2001
    final titleLower = course.title.toLowerCase();
    final slugLower = course.slug.toLowerCase();
    if (slugLower.contains('income-tax') ||
        slugLower.contains('mastering') ||
        titleLower.contains('income tax') ||
        titleLower.contains('mastering income tax')) {
      return 'com.premiertaxschool.course.income_tax';
    }
    final sanitizedSlug = course.slug.replaceAll('-', '_');
    return sanitizedSlug.isNotEmpty
        ? 'com.premiertaxschool.course.$sanitizedSlug'
        : 'com.premiertaxschool.course.income_tax';
  }

  /// Queries StoreKit for ProductDetails corresponding to available courses.
  Future<void> loadProducts(List<Course> courses) async {
    if (!_isAvailable || courses.isEmpty) return;

    _isLoadingProducts = true;
    notifyListeners();

    final Set<String> productIds = {};
    for (final course in courses) {
      final pId = resolveAppleProductId(course);
      productIds.add(pId);
      _productIdToCourseId[pId] = course.id;
    }

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        productIds,
      );

      if (response.error != null) {
        debugPrint('IapProvider: queryProductDetails error: ${response.error}');
      }

      for (final product in response.productDetails) {
        _products[product.id] = product;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          'IapProvider: Product IDs not found in App Store Connect: ${response.notFoundIDs}',
        );
      }
    } catch (e) {
      debugPrint('IapProvider: loadProducts exception: $e');
    } finally {
      _isLoadingProducts = false;
      notifyListeners();
    }
  }

  /// Helper to get the StoreKit ProductDetails for a given course.
  ProductDetails? getProductForCourse(Course course) {
    if (course.appleProductId != null &&
        _products.containsKey(course.appleProductId)) {
      return _products[course.appleProductId];
    }
    final fallbackId = resolveAppleProductId(course);
    return _products[fallbackId];
  }

  /// Formatted localized price for a course (or fallback to empty string).
  String? getPriceForCourse(Course course) {
    return getProductForCourse(course)?.price;
  }

  /// Initiates a StoreKit Non-Consumable course purchase.
  Future<bool> buyCourse(Course course) async {
    if (!_isAvailable) {
      _errorMessage = 'In-App Purchases are only available on iOS devices.';
      notifyListeners();
      return false;
    }

    final productDetails = getProductForCourse(course);
    if (productDetails == null) {
      _errorMessage =
          'This course is currently preparing for App Store availability.';
      notifyListeners();
      return false;
    }

    _isPurchasing = true;
    _purchasingCourseId = course.id;
    _errorMessage = null;
    notifyListeners();

    try {
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      final initiated = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      if (!initiated) {
        _isPurchasing = false;
        _purchasingCourseId = null;
        notifyListeners();
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('IapProvider: buyCourse exception: $e');
      _isPurchasing = false;
      _purchasingCourseId = null;
      _errorMessage = 'Could not start purchase: $e';
      notifyListeners();
      return false;
    }
  }

  /// Restores previous non-consumable Apple purchases.
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    _isRestoring = true;
    _isPurchasing = true;
    _errorMessage = null;
    _successMessage = null;
    _restoredCount = 0;
    notifyListeners();

    try {
      await _iap.restorePurchases();
      // Allow StoreKit asynchronous stream up to 6 seconds to deliver and process restored transactions
      await Future.delayed(const Duration(seconds: 6));
      if (_restoredCount == 0 && _errorMessage == null) {
        _errorMessage = 'No previous purchases found to restore.';
      }
    } catch (e) {
      debugPrint('IapProvider: restorePurchases exception: $e');
      _errorMessage = 'Failed to restore purchases: $e';
    } finally {
      _isRestoring = false;
      _isPurchasing = false;
      notifyListeners();
    }
  }

  /// Stream listener handling all incoming StoreKit purchase transactions.
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint(
        'IapProvider: Purchase update for ${purchaseDetails.productID}, status: ${purchaseDetails.status}',
      );

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _isPurchasing = true;
          _errorMessage = null;
          notifyListeners();
          break;

        case PurchaseStatus.purchased:
          _isPurchasing = true;
          notifyListeners();
          await _verifyAndDeliverProduct(purchaseDetails);
          _isPurchasing = false;
          _purchasingCourseId = null;
          notifyListeners();
          break;

        case PurchaseStatus.restored:
          _restoredCount++;
          _isPurchasing = true;
          notifyListeners();
          await _verifyAndDeliverProduct(purchaseDetails);
          _isPurchasing = false;
          _purchasingCourseId = null;
          notifyListeners();
          break;

        case PurchaseStatus.error:
          _isPurchasing = false;
          _purchasingCourseId = null;
          _errorMessage = purchaseDetails.error?.message ?? 'Purchase failed';
          debugPrint('IapProvider: Purchase error: ${purchaseDetails.error}');
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
          notifyListeners();
          break;

        case PurchaseStatus.canceled:
          _isPurchasing = false;
          _purchasingCourseId = null;
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
          notifyListeners();
          break;
      }
    }
  }

  /// Verifies transaction with NestJS backend (POST /api/iap/verify-apple) and finishes the transaction.
  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchaseDetails) async {
    try {
      final courseId = _findCourseIdForProductId(purchaseDetails.productID);
      // Cold-start fix (Issue #10): If courseId is null (e.g. cold launch before courses load),
      // DO NOT abort and DO NOT complete the purchase!
      // Send the request without courseId; the backend resolves the course via appleProductId.
      final Map<String, dynamic> requestPayload = {
        'productId': purchaseDetails.productID,
        'receiptData':
            purchaseDetails.verificationData.serverVerificationData,
        'transactionId': purchaseDetails.purchaseID,
      };
      if (courseId != null && courseId.isNotEmpty) {
        requestPayload['courseId'] = courseId;
      }

      final response = await ApiService.instance.dio.post(
        ApiConfig.verifyAppleIap,
        data: requestPayload,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint(
          'IapProvider: Successfully verified IAP transaction for product ${purchaseDetails.productID}',
        );
        _successMessage = 'Course unlocked! You are now enrolled.';
        _errorMessage = null;

        // 1. Refresh user session so user.isCourseEnrolled immediately reflects active status
        await _authProvider?.revalidateSession();

        // 2. ONLY NOW complete the transaction to remove it from Apple StoreKit queue
        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
        notifyListeners();
      } else {
        _errorMessage = 'Receipt validation failed on server (${response.statusCode}).';
        notifyListeners();
      }
    } on DioException catch (e) {
      debugPrint('IapProvider: Backend verification DioException: $e');
      final statusCode = e.response?.statusCode;

      if (statusCode != null &&
          (statusCode == 400 || statusCode == 404 || statusCode == 422)) {
        final serverMsg = (e.response?.data is Map)
            ? e.response?.data['message']?.toString()
            : null;
        _errorMessage =
            serverMsg ?? 'Invalid purchase receipt. Please contact support.';

        // If permanently revoked or refunded, complete purchase to remove from queue
        if (serverMsg != null &&
            (serverMsg.contains('revoked') || serverMsg.contains('refunded'))) {
          if (purchaseDetails.pendingCompletePurchase) {
            await _iap.completePurchase(purchaseDetails);
          }
        }
      } else {
        // Network error, timeout, 5xx, 401: DO NOT call completePurchase!
        // The transaction remains in Apple StoreKit queue and will be re-delivered on app restart or restore.
        _errorMessage =
            'Purchase received by Apple, but we couldn\'t reach our server to unlock the course. '
            'Your payment is safe—please check your connection and tap "Restore Previous Purchases" or restart the app.';
      }
      notifyListeners();
    } catch (e) {
      debugPrint('IapProvider: Unexpected verification error: $e');
      _errorMessage = 'Error processing purchase: $e';
      notifyListeners();
    }
  }

  String? _findCourseIdForProductId(String productId) {
    if (_productIdToCourseId.containsKey(productId)) {
      return _productIdToCourseId[productId];
    }
    for (final c in _lastCourses) {
      if (c.appleProductId == productId ||
          resolveAppleProductId(c) == productId) {
        return c.id;
      }
    }
    return null;
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
