import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/models/course.dart';
import 'package:premier_lms/widgets/star_rating.dart';

/// Course card widget matching CourseCard.tsx component.
class CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback? onTap;

  const CourseCard({super.key, required this.course, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: course.thumbnail,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.bgLight,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: AppColors.bgLight,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.textSecondary),
                    ),
                  ),
                  // Badge
                  if (course.badge != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _badgeColor(course.badge!),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _badgeText(course.badge!),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _badgeTextColor(course.badge!),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Card body
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Instructor
                  Text(
                    course.instructor,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Rating
                  Row(
                    children: [
                      StarRating(rating: course.rating, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${course.rating}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${course.reviewCount})',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Metadata
                  Text(
                    '${course.lessonCount} Lessons • ${course.duration}h total',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Price
                  _buildPrice(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrice() {
    if (course.isFree) {
      return const Text(
        'FREE',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF16A34A),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 6,
      children: [
        Text(
          'Rs. ${_formatPrice(course.price!)}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (course.originalPrice != null)
          Text(
            'Rs. ${_formatPrice(course.originalPrice!)}',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        if (course.discountPercent != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${course.discountPercent}% off',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF92400E),
              ),
            ),
          ),
      ],
    );
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  Color _badgeColor(String badge) {
    switch (badge) {
      case 'bestseller':
        return AppColors.badgeBestseller;
      case 'new':
        return AppColors.badgeNew;
      case 'free':
        return AppColors.badgeFree;
      default:
        return AppColors.primaryGreen;
    }
  }

  Color _badgeTextColor(String badge) {
    switch (badge) {
      case 'bestseller':
        return AppColors.badgeBestsellerText;
      default:
        return Colors.white;
    }
  }

  String _badgeText(String badge) {
    switch (badge) {
      case 'bestseller':
        return 'BESTSELLER';
      case 'new':
        return 'NEW';
      case 'free':
        return 'FREE';
      default:
        return badge.toUpperCase();
    }
  }
}
