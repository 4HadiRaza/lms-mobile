import 'package:flutter/material.dart';

/// Star rating display widget matching StarRating.tsx.
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final bool showValue;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 16,
    this.showValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          final starValue = index + 1;
          IconData icon;
          if (rating >= starValue) {
            icon = Icons.star_rounded;
          } else if (rating >= starValue - 0.5) {
            icon = Icons.star_half_rounded;
          } else {
            icon = Icons.star_outline_rounded;
          }
          return Icon(
            icon,
            size: size,
            color: const Color(0xFFFBBF24),
          );
        }),
        if (showValue) ...[
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: size * 0.75,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ],
    );
  }
}
