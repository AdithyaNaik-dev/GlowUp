import 'package:flutter/material.dart';
import '../config/theme.dart';

class StreakCard extends StatelessWidget {
  final int currentStreak;
  final int bestStreak;

  const StreakCard({
    super.key,
    required this.currentStreak,
    required this.bestStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$currentStreak',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Day Streak',
                      style: TextStyle(
                        color: context.appTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Best: $bestStreak days',
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.emoji_events_rounded,
            color: AppColors.warning,
            size: 26,
          ),
          const SizedBox(width: 8),
          
        ],
      ),
    );
  }
}
