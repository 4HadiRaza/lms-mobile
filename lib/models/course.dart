/// Lesson within a module.
class Lesson {
  final String id;
  final String title;
  final int duration; // minutes
  final String type; // 'video', 'article', 'quiz'
  final bool isPreview;

  const Lesson({
    required this.id,
    required this.title,
    required this.duration,
    this.type = 'video',
    this.isPreview = false,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      duration: json['duration'] ?? 30,
      type: json['type'] ?? 'video',
      isPreview: json['isPreview'] ?? false,
    );
  }
}

/// Module containing lessons.
class Module {
  final String id;
  final String title;
  final List<Lesson> lessons;

  const Module({
    required this.id,
    required this.title,
    this.lessons = const [],
  });

  factory Module.fromJson(Map<String, dynamic> json) {
    return Module(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      lessons: (json['lessons'] as List<dynamic>?)
              ?.map((l) => Lesson.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  int get lessonCount => lessons.length;
}

/// Course model matching the website's Course interface and API mapping.
class Course {
  final String id;
  final String slug;
  final String title;
  final String description;
  final String longDescription;
  final String instructor;
  final String instructorId;
  final String category;
  final String level;
  final int duration; // hours
  final List<Module> modules;
  final double rating;
  final int reviewCount;
  final int enrollmentCount;
  final double? price;
  final double? originalPrice;
  final int? discountPercent;
  final String thumbnail;
  final int lessonCount;
  final List<String> tags;
  final String? badge;
  final String? batchName;
  final List<String> batchNames;
  final String lastUpdated;
  final String language;
  final List<String> whatYouWillLearn;
  final List<String> requirements;
  final List<Map<String, dynamic>> reviews;

  const Course({
    required this.id,
    required this.slug,
    required this.title,
    this.description = '',
    this.longDescription = '',
    this.instructor = 'Premier Expert',
    this.instructorId = '',
    this.category = 'Tax & Accounting',
    this.level = 'Intermediate',
    this.duration = 12,
    this.modules = const [],
    this.rating = 4.8,
    this.reviewCount = 0,
    this.enrollmentCount = 0,
    this.price,
    this.originalPrice,
    this.discountPercent,
    this.thumbnail =
        'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=600&h=340&fit=crop',
    this.lessonCount = 0,
    this.tags = const [],
    this.badge,
    this.batchName,
    this.batchNames = const [],
    this.lastUpdated = '',
    this.language = 'English & Urdu',
    this.whatYouWillLearn = const [],
    this.requirements = const [],
    this.reviews = const [],
  });

  /// Maps from the backend API response to the Course model,
  /// replicating the mapping logic in page.tsx and courses/page.tsx.
  factory Course.fromApiJson(Map<String, dynamic> json) {
    final reviewsList = json['reviews'] as List<dynamic>? ?? [];
    final reviewsCount = reviewsList.length;
    final calculatedRating = reviewsCount > 0
        ? double.parse(
            (reviewsList.fold<double>(
                        0, (sum, r) => sum + ((r['rating'] as num?) ?? 0)) /
                    reviewsCount)
                .toStringAsFixed(1))
        : 4.8;

    final modulesList = json['modules'] as List<dynamic>? ?? [];
    final calculatedLessonCount = modulesList.fold<int>(
      0,
      (sum, m) => sum + ((m['lessons'] as List<dynamic>?)?.length ?? 0),
    );

    final originalFee = (json['originalFee'] as num?)?.toDouble();
    final discountedFee = (json['discountedFee'] as num?)?.toDouble();
    final coursePrice = (discountedFee != null && discountedFee == 0)
        ? null
        : discountedFee;

    int? discount;
    if (originalFee != null &&
        discountedFee != null &&
        originalFee > discountedFee) {
      discount =
          ((originalFee - discountedFee) / originalFee * 100).round();
    }

    final name = json['name'] ?? '';

    String? extractedBatchName;
    List<String> extractedBatchNames = [];
    if (json['batches'] != null && json['batches'] is List) {
      final bList = json['batches'] as List;
      extractedBatchNames = bList
          .map((b) => (b['name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .toList();
      if (extractedBatchNames.isNotEmpty) {
        extractedBatchName = extractedBatchNames.first;
      }
    } else if (json['batchName'] != null &&
        json['batchName'].toString().isNotEmpty) {
      extractedBatchName = json['batchName'].toString();
      extractedBatchNames = [extractedBatchName];
    } else if (json['batch'] != null && json['batch'] is Map) {
      extractedBatchName = json['batch']['name']?.toString();
      if (extractedBatchName != null && extractedBatchName.isNotEmpty) {
        extractedBatchNames = [extractedBatchName];
      }
    }

    return Course(
      id: json['id']?.toString() ?? '',
      slug: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
      title: name,
      description: json['description'] ??
          'Learn professional practices in tax & accounting.',
      longDescription: json['longDescription'] ??
          'This course provides complete, practical training.',
      instructor: json['instructorName'] ?? 'Premier Academy Faculty',
      instructorId: json['instructorId']?.toString() ?? '',
      category: json['category'] ?? 'Tax & Accounting',
      level: json['level'] ?? 'Intermediate',
      duration: json['duration'] ?? 12,
      modules: modulesList
          .map((m) => Module.fromJson(m as Map<String, dynamic>))
          .toList(),
      rating: calculatedRating,
      reviewCount: reviewsCount > 0 ? reviewsCount : 15,
      enrollmentCount: 120,
      price: coursePrice,
      originalPrice: originalFee,
      discountPercent: discount,
      thumbnail: json['thumbnail'] ??
          'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=600&h=340&fit=crop',
      lessonCount: calculatedLessonCount > 0 ? calculatedLessonCount : 24,
      tags: [
        json['category'] ?? 'Tax',
        json['level'] ?? 'Intermediate',
      ],
      badge: json['badge'],
      batchName: extractedBatchName,
      batchNames: extractedBatchNames,
      lastUpdated: json['lastUpdated'] ?? 'June 2026',
      language: json['language'] ?? 'English & Urdu',
      whatYouWillLearn: (json['whatYouWillLearn'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [
            'Understand core concepts and frameworks',
            'Apply knowledge to real-world scenarios',
          ],
      requirements: (json['requirements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['Basic understanding of accounting principles'],
      reviews: reviewsList
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList(),
    );
  }

  bool get isFree => price == null;
  int get totalLessons =>
      modules.fold(0, (sum, m) => sum + m.lessonCount);
}

/// Instructor info for course detail page.
class Instructor {
  final String name;
  final String title;
  final double rating;
  final int coursesCount;
  final int studentsCount;
  final String bio;
  final String image;

  const Instructor({
    required this.name,
    this.title = '',
    this.rating = 4.9,
    this.coursesCount = 0,
    this.studentsCount = 0,
    this.bio = '',
    this.image =
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
  });

  factory Instructor.fromApiJson(Map<String, dynamic> courseJson) {
    return Instructor(
      name: courseJson['instructorName'] ?? 'Premier Academy Faculty',
      title: courseJson['instructorTitle'] ??
          'Senior Tax Consultants & Practitioners',
      rating: 4.9,
      coursesCount: 8,
      studentsCount: 1200,
      bio: courseJson['instructorBio'] ??
          'Our faculty consists of leading tax consultants, legal experts, '
              'and chartered accountants in Pakistan with decades of experience.',
      image: courseJson['instructorImage'] ??
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
    );
  }
}
