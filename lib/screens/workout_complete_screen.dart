import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
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
  bool _showContent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdService().showInterstitialAd(
        onAdDismissed: _startAnimations,
      );
    });
  }

  void _startAnimations() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dataService = DataService();
    final streak = dataService.currentStreak;
    final exercises = dataService.getExercisesForDayWithReps(widget.day);

    return Scaffold(
      bottomNavigationBar: const BannerAdWidget(),
      body: Stack(
        children: [
          // Confetti background
          if (_showContent)
            Positioned.fill(
              child: IgnorePointer(
                child: DotLottieLoader.fromAsset(
                  'assets/animation/Confetti - Full Screen.lottie',
                  frameBuilder: (ctx, dotlottie) {
                    if (dotlottie != null) {
                      return Lottie.memory(
                        dotlottie.animations.values.single,
                        fit: BoxFit.cover,
                        repeat: false,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Completed tick animation
                SizedBox(
                  width: 240,
                  height: 240,
                  child: _showContent
                      ? DotLottieLoader.fromAsset(
                          'assets/animation/Completed.lottie',
                          frameBuilder: (ctx, dotlottie) {
                            if (dotlottie != null) {
                              return Lottie.memory(
                                dotlottie.animations.values.single,
                                fit: BoxFit.contain,
                                repeat: true,
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        )
                      : const SizedBox.shrink(),
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
        ],
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

