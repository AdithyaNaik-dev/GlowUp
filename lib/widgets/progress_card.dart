import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/data_service.dart';

class ProgressCard extends StatefulWidget {
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
  State<ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends State<ProgressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final isPostChallenge = dataService.isInPostChallengeMode;
    final clampedProgress = widget.progress.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
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
                  '${widget.completedDays} / ${widget.totalDays} days',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                Text(
                  '${dataService.totalWorkoutsCompleted} workouts',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (!isPostChallenge)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(double.infinity, 8),
                      painter: _ShimmerProgressPainter(
                        progress: clampedProgress,
                        shimmerValue: _shimmerController.value,
                        backgroundColor: context.isDark
                            ? context.appSurface
                            : const Color(0xFFEEEEEE),
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            isPostChallenge
                ? 'Keep building your glow-up streak'
                : '${(widget.progress * 100).toStringAsFixed(0)}% of 30-day challenge',
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ShimmerProgressPainter extends CustomPainter {
  final double progress;
  final double shimmerValue;
  final Color backgroundColor;

  _ShimmerProgressPainter({
    required this.progress,
    required this.shimmerValue,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6),
      ),
      bgPaint,
    );

    if (progress <= 0) return;

    final progressWidth = size.width * progress;

    final gradient = LinearGradient(
      colors: const [
        AppColors.primary,
        Color(0xFFFF8A65),
        AppColors.primary,
      ],
      stops: [
        (shimmerValue - 0.3).clamp(0.0, 1.0),
        shimmerValue,
        (shimmerValue + 0.3).clamp(0.0, 1.0),
      ],
    );

    final progressPaint = Paint()
      ..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, progressWidth, size.height),
      );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, progressWidth, size.height),
        const Radius.circular(6),
      ),
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ShimmerProgressPainter oldDelegate) =>
      oldDelegate.shimmerValue != shimmerValue ||
      oldDelegate.progress != progress;
}
