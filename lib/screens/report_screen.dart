import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../services/data_service.dart';

class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final completedDays = dataService.completedDays;
    final currentStreak = dataService.currentStreak;
    final bestStreak = dataService.bestStreak;
    final progress = dataService.progressPercent;
    final totalExercises = completedDays.length * 10;
    final totalMinutes = completedDays.length * 30;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Report',
                  style: GoogleFonts.poppins(
                    color: context.appTextPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _buildSummaryRow(context, completedDays, totalExercises, totalMinutes),
                const SizedBox(height: 24),
                _buildHistorySection(context, dataService, completedDays, currentStreak),
                const SizedBox(height: 24),
                _buildProgressSection(context, progress, completedDays.length),
                const SizedBox(height: 24),
                _buildStreakSection(context, currentStreak, bestStreak, completedDays.length),
                const SizedBox(height: 24),
                _buildCompletedSection(context, dataService, completedDays),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
      BuildContext context, Set<int> completedDays, int totalExercises, int totalMinutes) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _summaryItem(context, Icons.fitness_center_rounded,
              '${completedDays.length}', 'Workout', AppColors.primary),
          _verticalDivider(context),
          _summaryItem(context, Icons.local_fire_department_rounded,
              '$totalExercises', 'Exercises', const Color(0xFFFF9800)),
          _verticalDivider(context),
          _summaryItem(context, Icons.timer_rounded,
              '$totalMinutes', 'Minute', const Color(0xFF2196F3)),
        ],
      ),
    );
  }

  Widget _summaryItem(
      BuildContext context, IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: context.appTextHint,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider(BuildContext context) {
    return Container(
      height: 50,
      width: 1,
      color: context.appDivider,
    );
  }

  Widget _buildHistorySection(
      BuildContext context, DataService dataService, Set<int> completedDays, int streak) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'History',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'All records',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appCardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appDivider),
          ),
          child: Column(
            children: [
              _buildWeekCalendar(context, completedDays, dataService),
              Divider(color: context.appDivider, height: 28),
              Row(
                children: [
                  Text(
                    'Day Streak',
                    style: TextStyle(
                      color: context.appTextHint,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      color: Color(0xFFFF9800), size: 22),
                  const SizedBox(width: 6),
                  Text(
                    '$streak',
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekCalendar(
      BuildContext context, Set<int> completedDays, DataService dataService) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final currentDay = dataService.currentDay;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(7, (i) {
        final date = weekStart.add(Duration(days: i));
        final isToday = date.day == now.day &&
            date.month == now.month &&
            date.year == now.year;

        final dayDiff = date.difference(now).inDays;
        final challengeDay = currentDay + dayDiff;
        final isCompleted = completedDays.contains(challengeDay);

        return Column(
          children: [
            Text(
              dayLabels[i],
              style: TextStyle(
                color: context.appTextHint,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary
                    : isToday
                        ? AppColors.primary.withAlpha(30)
                        : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isCompleted
                    ? Border.all(color: AppColors.primary, width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: isCompleted
                        ? Colors.white
                        : isToday
                            ? AppColors.primary
                            : context.appTextPrimary,
                    fontSize: 15,
                    fontWeight:
                        isToday || isCompleted ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProgressSection(
      BuildContext context, double progress, int completedDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Challenge Progress',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appCardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.appDivider),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current',
                          style: TextStyle(
                            color: context.appTextHint,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Day $completedDays',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'of 30',
                          style: TextStyle(
                            color: context.appTextHint,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _miniStat(context, 'Target', '30'),
                      const SizedBox(height: 8),
                      _miniStat(context, 'Remaining', '${30 - completedDays}'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: context.isDark
                      ? context.appSurface
                      : const Color(0xFFEEEEEE),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _phaseLabel(context, 'Foundation',
                      completedDays >= 1, completedDays >= 10),
                  _phaseLabel(context, 'Build',
                      completedDays >= 11, completedDays >= 20),
                  _phaseLabel(context, 'Peak',
                      completedDays >= 21, completedDays >= 30),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniStat(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(
          '$label  ',
          style: TextStyle(
            color: context.appTextHint,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _phaseLabel(
      BuildContext context, String label, bool started, bool completed) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed
                ? AppColors.primary
                : started
                    ? AppColors.primary.withAlpha(120)
                    : context.appDivider,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: started ? context.appTextSecondary : context.appTextHint,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakSection(
      BuildContext context, int currentStreak, int bestStreak, int completedDays) {
    return Row(
      children: [
        Expanded(
          child: _recordCard(
            context,
            icon: Icons.local_fire_department_rounded,
            value: '$currentStreak',
            label: 'Current\nStreak',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _recordCard(
            context,
            icon: Icons.emoji_events_rounded,
            value: '$bestStreak',
            label: 'Best\nStreak',
            color: const Color(0xFFFF9800),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _recordCard(
            context,
            icon: Icons.check_circle_rounded,
            value: '$completedDays',
            label: 'Days\nDone',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  Widget _recordCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appDivider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.appTextHint,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSection(
      BuildContext context, DataService dataService, Set<int> completedDays) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Completed Workouts',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 14),
        if (completedDays.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: context.appCardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: context.appDivider),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.fitness_center_rounded,
                  size: 48,
                  color: context.appTextHint,
                ),
                const SizedBox(height: 12),
                Text(
                  'No workouts completed yet.\nStart your first workout today!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appTextHint,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...() {
            final sortedDays = completedDays.toList()..sort((a, b) => b.compareTo(a));
            return sortedDays.map((day) {
              final plan = dataService.getDayPlan(day);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.appCardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.appDivider),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Icon(Icons.check_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day $day',
                            style: TextStyle(
                              color: context.appTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            plan != null
                                ? '${plan.totalExercises} exercises • ${plan.phaseLabel}'
                                : '10 exercises',
                            style: TextStyle(
                              color: context.appTextHint,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 24),
                  ],
                ),
              );
            });
          }(),
      ],
    );
  }
}
