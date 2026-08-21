/// Enrollment item containing course and batch relationship.
class EnrollmentInfo {
  final String id;
  final String courseName;
  final String? courseId;
  final String? batchName;
  final String? batchId;
  final bool isActive;
  final String? batchStatus;

  const EnrollmentInfo({
    required this.id,
    required this.courseName,
    this.courseId,
    this.batchName,
    this.batchId,
    this.isActive = true,
    this.batchStatus,
  });

  factory EnrollmentInfo.fromJson(Map<String, dynamic> json) {
    final courseData = json['course'] as Map<String, dynamic>?;
    final batchData = json['batch'] as Map<String, dynamic>?;

    final cName = courseData?['name']?.toString() ??
        json['courseName']?.toString() ??
        '';
    final bName = batchData?['name']?.toString() ??
        json['batchName']?.toString() ??
        'Batch-1';

    return EnrollmentInfo(
      id: json['id']?.toString() ?? '',
      courseName: cName,
      courseId: courseData?['id']?.toString() ?? json['courseId']?.toString(),
      batchName: bName,
      batchId: json['batchId']?.toString(),
      isActive: json['isActive'] ?? true,
      batchStatus: batchData?['status']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courseName': courseName,
        'courseId': courseId,
        'batchName': batchName,
        'batchId': batchId,
        'isActive': isActive,
        'batchStatus': batchStatus,
      };
}

/// User model matching the AuthContext.tsx User interface.
class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String avatar;
  final List<String> enrolledCourses;
  final List<EnrollmentInfo> enrollments;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar =
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
    this.enrolledCourses = const [],
    this.enrollments = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    List<String> courses = [];
    List<EnrollmentInfo> parsedEnrollments = [];

    if (json['enrollments'] != null && json['enrollments'] is List) {
      for (final e in (json['enrollments'] as List<dynamic>)) {
        if (e is Map) {
          final enr = EnrollmentInfo.fromJson(Map<String, dynamic>.from(e));
          parsedEnrollments.add(enr);
          if (enr.courseName.isNotEmpty && !courses.contains(enr.courseName)) {
            courses.add(enr.courseName);
          }
        }
      }
    }

    if (courses.isEmpty &&
        json['enrolledCourses'] != null &&
        json['enrolledCourses'] is List) {
      courses = (json['enrolledCourses'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
    }

    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      avatar: json['avatar'] ??
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
      enrolledCourses: courses,
      enrollments: parsedEnrollments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatar': avatar,
        'enrolledCourses': enrolledCourses,
        'enrollments': enrollments.map((e) => e.toJson()).toList(),
      };

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
  bool get isPending => role == 'pending';
  bool get isActive => role != 'pending';
  bool get hasEnrollments => enrolledCourses.isNotEmpty;
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';

  /// Primary batch name if available
  String? get primaryBatchName =>
      enrollments.isNotEmpty ? enrollments.first.batchName : null;

  /// Check if the user is enrolled in a specific course by title or id
  bool isCourseEnrolled(String courseTitleOrId) {
    if (courseTitleOrId.isEmpty) return false;
    final clean = courseTitleOrId.trim().toLowerCase();

    final matchesEnrollment = enrollments.any((e) =>
        e.courseName.trim().toLowerCase() == clean ||
        (e.courseId != null && e.courseId!.toLowerCase() == clean));

    if (matchesEnrollment) return true;

    return enrolledCourses.any((c) => c.trim().toLowerCase() == clean);
  }

  /// Get batch name for a specific course
  String? getBatchNameForCourse(String courseTitleOrId) {
    if (courseTitleOrId.isEmpty) return primaryBatchName;
    final clean = courseTitleOrId.trim().toLowerCase();

    for (final e in enrollments) {
      if (e.courseName.trim().toLowerCase() == clean ||
          (e.courseId != null && e.courseId!.toLowerCase() == clean)) {
        return e.batchName;
      }
    }
    return primaryBatchName;
  }
}
