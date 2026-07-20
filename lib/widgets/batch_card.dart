import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/models/batch.dart';

/// Batch card for the home page batch lists.
class BatchCard extends StatelessWidget {
  final Batch batch;
  final bool isUpcoming;

  const BatchCard({
    super.key,
    required this.batch,
    this.isUpcoming = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: CachedNetworkImage(
              imageUrl: batch.thumbnail,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: AppColors.bgLight),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.bgLight,
                child: const Icon(Icons.image_not_supported_outlined),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  batch.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  batch.startDate != null
                      ? '${isUpcoming ? "Starts" : "Started"}: ${DateFormat('MMM d, yyyy').format(batch.startDate!)}'
                      : '',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
