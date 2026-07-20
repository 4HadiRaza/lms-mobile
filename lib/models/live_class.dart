import 'package:intl/intl.dart';

/// Live class model matching the website's LiveClass interface.
class LiveClass {
  final String id;
  final String category;
  final String title;
  final String date;
  final String time;
  final String instructor;
  final String thumbnail;
  final String? courseName;
  final String? batchName;
  final DateTime? scheduledStart;

  const LiveClass({
    required this.id,
    required this.title,
    this.category = 'Live Class',
    this.date = '',
    this.time = '',
    this.instructor = 'Premier Expert',
    this.thumbnail =
        'https://images.unsplash.com/photo-1531482615713-2afd69097998?w=600&h=450&fit=crop',
    this.courseName,
    this.batchName,
    this.scheduledStart,
  });

  /// From the public /classes/public/upcoming API response.
  factory LiveClass.fromPublicJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['scheduledStart'] ?? '');
    final dateStr = start != null
        ? DateFormat('MMM d, yyyy').format(start)
        : '';
    final timeStr = start != null
        ? DateFormat('hh:mm a').format(start)
        : '';

    return LiveClass(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      category: json['courseName'] ?? 'Live Class',
      date: dateStr,
      time: timeStr,
      instructor: 'Premier Expert',
      thumbnail:
          'https://images.unsplash.com/photo-1531482615713-2afd69097998?w=600&h=450&fit=crop',
      courseName: json['courseName'],
      batchName: json['batchName'],
      scheduledStart: start,
    );
  }

  /// From the student dashboard /classes/my/upcoming or /classes/my/past API.
  factory LiveClass.fromStudentJson(Map<String, dynamic> json) {
    final start = DateTime.tryParse(json['scheduledStart'] ?? '');

    return LiveClass(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      category: json['courseName'] ?? 'Live Class',
      date: start != null
          ? DateFormat('MMM d, yyyy').format(start)
          : '',
      time: start != null ? DateFormat('hh:mm a').format(start) : '',
      instructor: 'Premier Expert',
      courseName: json['courseName'],
      batchName: json['batchName'],
      scheduledStart: start,
    );
  }

  String get formattedDateTime {
    if (date.isNotEmpty && time.isNotEmpty) return '$date • $time';
    if (date.isNotEmpty) return date;
    if (scheduledStart != null) {
      return DateFormat('MMM d, yyyy – hh:mm a').format(scheduledStart!);
    }
    return '';
  }
}
