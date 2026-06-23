import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/data_service.dart';
import '../services/ad_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'main_shell.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  final int day;

  const WorkoutCompleteScreen({super.key, required this.day});

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  @override
  void initState() {
    super.initState();
    // Show interstitial ad after workout completion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().showInterstitialAd();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final streak = dataService.currentStreak;
    final exercises = dataService.getExercisesForDayWithReps(widget.day);

    return Scaffold(
      bottomNavigationBar: const BannerAdWidget(),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Celebration icon
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary,
                        AppColors.secondary.withAlpha(180),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withAlpha(60),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.black,
                    size: 72,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Workout Complete! 🎉',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Day ${widget.day} done! You\'re one step closer\nto your glow up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appTextSecondary,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statItem(Icons.local_fire_department_rounded,
                        '$streak', 'Streak', AppColors.primary),
                    _statItem(Icons.timer_rounded, '~${exercises.length * 3}', 'Minutes',
                        AppColors.secondary),
                    _statItem(Icons.fitness_center_rounded, '${exercises.length}',
                        'Exercises', AppColors.warning),
                  ],
                ),
                const SizedBox(height: 40),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const MainShell(),
                        ),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Back to Home',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: context.appTextSecondary,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

