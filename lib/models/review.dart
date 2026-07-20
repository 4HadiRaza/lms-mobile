/// Review model matching the website's Review interface.
class Review {
  final String id;
  final String name;
  final double rating;
  final String content;
  final String date;

  const Review({
    required this.id,
    required this.name,
    required this.rating,
    required this.content,
    this.date = '',
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Anonymous',
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      content: json['content'] ?? '',
      date: json['date'] ?? '',
    );
  }

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}
