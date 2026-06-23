import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/data_service.dart';

class ProgressCard extends StatelessWidget {
  final double progress;
  final int completedDays;
  final int totalDays;

  const ProgressCard({
    super.key,
    required this.progress,
    required this.completedDays,
    this.totalDays = 30,
  });

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final isPostChallenge = dataService.isInPostChallengeMode;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isPostChallenge ? 'Total Workouts' : 'Your Progress',
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isPostChallenge)
                Text(
                  '$completedDays / $totalDays days',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  '${dataService.totalWorkoutsCompleted} workouts',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isPostChallenge)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: context.appSurface,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.secondary),
              ),
            )
          else
            Container(
              height: 12,
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  'Ongoing progress',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            isPostChallenge
                ? 'Keep building your glow-up streak'
                : '${(progress * 100).toStringAsFixed(0)}% of 30-day challenge',
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
