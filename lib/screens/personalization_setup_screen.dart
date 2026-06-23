import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/data_service.dart';
import '../widgets/glow_button.dart';
import 'auth_screen.dart';

class PersonalizationSetupScreen extends StatefulWidget {
  const PersonalizationSetupScreen({super.key});

  @override
  State<PersonalizationSetupScreen> createState() =>
      _PersonalizationSetupScreenState();
}

class _PersonalizationSetupScreenState
    extends State<PersonalizationSetupScreen> {
  String? _selectedLevel;

  final List<_FitnessOption> _options = [
    _FitnessOption(
      level: 'beginner',
      label: 'Beginner',
      description: '10 reps per exercise',
      icon: Icons.spa_rounded,
      color: AppColors.success,
    ),
    _FitnessOption(
      level: 'medium',
      label: 'Medium',
      description: '15 reps per exercise',
      icon: Icons.fitness_center_rounded,
      color: AppColors.warning,
    ),
    _FitnessOption(
      level: 'advanced',
      label: 'Advanced',
      description: '20 reps per exercise',
      icon: Icons.whatshot_rounded,
      color: AppColors.primary,
    ),
  ];

  void _onContinue() async {
    if (_selectedLevel == null) return;
    final dataService = DataService();
    await dataService.setFitnessLevel(_selectedLevel!);
    await dataService.setPersonalizationComplete();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const AuthScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Select your\nfitness level',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'This will customize your workout intensity',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(160),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              ...List.generate(_options.length, (index) {
                final option = _options[index];
                final isSelected = _selectedLevel == option.level;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedLevel = option.level),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? option.color.withAlpha(25)
                            : Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? option.color
                              : Theme.of(context).dividerColor,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: option.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              option.icon,
                              color: option.color,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  option.description,
                                  style: TextStyle(
                                    color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(160),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? option.color
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? option.color
                                    : AppColors.textHint,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: AnimatedOpacity(
                  opacity: _selectedLevel != null ? 1.0 : 0.4,
                  duration: const Duration(milliseconds: 300),
                  child: GlowButton(
                    text: 'Continue',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: _selectedLevel != null ? _onContinue : () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FitnessOption {
  final String level;
  final String label;
  final String description;
  final IconData icon;
  final Color color;

  _FitnessOption({
    required this.level,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
  });
}
