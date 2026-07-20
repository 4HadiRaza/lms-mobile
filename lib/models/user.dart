/// User model matching the AuthContext.tsx User interface.
class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String avatar;
  final List<String> enrolledCourses;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.avatar =
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
    this.enrolledCourses = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'student',
      avatar: json['avatar'] ??
          'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=100&h=100&fit=crop',
      enrolledCourses: (json['enrollments'] as List<dynamic>?)
              ?.map((e) => (e['course']?['name'] ?? '').toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
        'avatar': avatar,
        'enrolledCourses': enrolledCourses,
      };

  bool get isAdmin => role == 'admin';
  bool get isStudent => role == 'student';
  bool get isPending => role == 'pending';
  bool get isActive => role != 'pending';
  bool get hasEnrollments => enrolledCourses.isNotEmpty;
  String get initials => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
