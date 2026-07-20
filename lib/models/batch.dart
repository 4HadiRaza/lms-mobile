import 'package:premier_lms/config/api_config.dart';

/// Batch model matching the website's Batch interface.
class Batch {
  final String id;
  final String name;
  final String thumbnail;
  final DateTime? startDate;
  final List<Map<String, dynamic>> courses;

  const Batch({
    required this.id,
    required this.name,
    this.thumbnail =
        'https://images.unsplash.com/photo-1554224155-6726b3ff858f?w=700&h=400&fit=crop',
    this.startDate,
    this.courses = const [],
  });

  factory Batch.fromJson(Map<String, dynamic> json) {
    return Batch(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      thumbnail: ApiConfig.mediaUrl(json['thumbnail']),
      startDate: DateTime.tryParse(json['startDate'] ?? ''),
      courses: (json['courses'] as List<dynamic>?)
              ?.map((c) => Map<String, dynamic>.from(c as Map))
              .toList() ??
          [],
    );
  }

  bool get isUpcoming =>
      startDate != null && startDate!.isAfter(DateTime.now());

  bool get isPastOrActive =>
      startDate != null && !startDate!.isAfter(DateTime.now());
}
