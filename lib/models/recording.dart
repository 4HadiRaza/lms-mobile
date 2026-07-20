/// Recording model matching the dashboard recordings data shape.
class Recording {
  final String id;
  final String title;
  final String courseName;
  final String? batchName;
  final String? classNo;
  final int duration; // minutes

  const Recording({
    required this.id,
    required this.title,
    required this.courseName,
    this.batchName,
    this.classNo,
    this.duration = 0,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      courseName: json['courseName'] ?? '',
      batchName: json['batchName'],
      classNo: json['classNo']?.toString(),
      duration: json['duration'] ?? 0,
    );
  }

  String get formattedDuration {
    if (duration == 0) return '0 mins';
    final hrs = duration ~/ 60;
    final mins = duration % 60;
    if (hrs > 0) {
      return '$hrs hr${hrs > 1 ? 's' : ''} $mins min${mins != 1 ? 's' : ''}';
    }
    return '$mins min${mins != 1 ? 's' : ''}';
  }

  String get displayTitle {
    if (classNo != null && classNo!.isNotEmpty) {
      return '[Class $classNo] $title';
    }
    return title;
  }
}
