import 'package:flutter/material.dart';
import 'package:premier_lms/config/theme.dart';
import 'package:premier_lms/models/recording.dart';

/// Recording list tile for the recordings screen.
class RecordingTile extends StatelessWidget {
  final Recording recording;
  final bool isPlaying;
  final VoidCallback? onPlay;

  const RecordingTile({
    super.key,
    required this.recording,
    this.isPlaying = false,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.borderLight.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      recording.formattedDuration,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: isPlaying ? null : onPlay,
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: isPlaying
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryGreen,
                          ),
                        )
                      : const Icon(
                          Icons.play_arrow_rounded,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
