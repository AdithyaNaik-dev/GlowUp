import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/data_service.dart';
import '../widgets/glow_button.dart';
import 'personalization_setup_screen.dart';

class HealthMetricsScreen extends StatefulWidget {
  const HealthMetricsScreen({super.key});

  @override
  State<HealthMetricsScreen> createState() => _HealthMetricsScreenState();
}

class _HealthMetricsScreenState extends State<HealthMetricsScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  double _weight = 65.0;
  int _heightCm = 170;
  int _age = 25;

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeMetrics();
    }
  }

  Future<void> _completeMetrics() async {
    final dataService = DataService();
    await dataService.setWeight(_weight);
    await dataService.setHeight(_heightCm / 100.0);
    await dataService.setAge(_age);
    await dataService.setHealthMetricsComplete();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PersonalizationSetupScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 4,
                        right: index == 2 ? 0 : 4,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 5,
                        decoration: BoxDecoration(
                          color: index <= _currentPage
                              ? AppColors.primary
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Step ${_currentPage + 1} of 3',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWeightPage(),
                  _buildHeightPage(),
                  _buildAgePage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              child: GlowButton(
                text: _currentPage == 2 ? 'Continue' : 'Next',
                icon: _currentPage == 2
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                onPressed: _nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightPage() {
    return _buildMetricPage(
      icon: Icons.monitor_weight_rounded,
      accentColor: AppColors.primary,
      title: "What's your\nweight?",
      subtitle: 'Helps calculate your BMI & track progress',
      displayValue: _weight.toStringAsFixed(_weight % 1 == 0 ? 0 : 1),
      unit: 'kg',
      slider: _buildSlider(
        value: _weight,
        min: 30,
        max: 200,
        divisions: 340,
        color: AppColors.primary,
        onChanged: (v) => setState(() => _weight = (v * 2).round() / 2),
      ),
    );
  }

  Widget _buildHeightPage() {
    final bmi = DataService().calculateBMI(_weight, _heightCm / 100.0);
    return _buildMetricPage(
      icon: Icons.height_rounded,
      accentColor: const Color(0xFF2196F3),
      title: "What's your\nheight?",
      subtitle: 'Used to calculate your BMI accurately',
      displayValue: _heightCm.toString(),
      unit: 'cm',
      slider: _buildSlider(
        value: _heightCm.toDouble(),
        min: 100,
        max: 220,
        divisions: 120,
        color: const Color(0xFF2196F3),
        onChanged: (v) => setState(() => _heightCm = v.round()),
      ),
      helperWidget: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withAlpha(15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2196F3).withAlpha(40)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.analytics_rounded,
                color: Color(0xFF2196F3), size: 18),
            const SizedBox(width: 8),
            Text(
              'Your BMI: ',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            Text(
              bmi.toStringAsFixed(1),
              style: const TextStyle(
                color: Color(0xFF2196F3),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgePage() {
    return _buildMetricPage(
      icon: Icons.cake_rounded,
      accentColor: const Color(0xFF9C27B0),
      title: 'How old\nare you?',
      subtitle: 'Customizes your workout intensity',
      displayValue: _age.toString(),
      unit: 'years',
      slider: _buildSlider(
        value: _age.toDouble(),
        min: 10,
        max: 80,
        divisions: 70,
        color: const Color(0xFF9C27B0),
        onChanged: (v) => setState(() => _age = v.round()),
      ),
    );
  }

  Widget _buildMetricPage({
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String displayValue,
    required String unit,
    required Widget slider,
    Widget? helperWidget,
  }) {
    return Stack(
      children: [
        Positioned(
          top: -30,
          right: -40,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withAlpha(15),
            ),
          ),
        ),
        Positioned(
          bottom: 40,
          left: -35,
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withAlpha(10),
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: 30,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withAlpha(20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withAlpha(180)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withAlpha(60),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 38),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 15,
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 24, horizontal: 40),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(10),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: accentColor.withAlpha(35),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            displayValue,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: 8, left: 4),
                            child: Text(
                              unit,
                              style: TextStyle(
                                color: accentColor.withAlpha(160),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    slider,
                    if (helperWidget != null) ...[
                      const SizedBox(height: 20),
                      helperWidget,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return SliderTheme(
      data: SliderThemeData(
        activeTrackColor: color,
        inactiveTrackColor: color.withAlpha(30),
        thumbColor: Colors.white,
        overlayColor: color.withAlpha(25),
        thumbShape: _ThumbShape(color: color),
        trackHeight: 8,
        trackShape: const RoundedRectSliderTrackShape(),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
      ),
    );
  }
}

class _ThumbShape extends SliderComponentShape {
  final Color color;
  const _ThumbShape({required this.color});

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(14);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;

    canvas.drawCircle(
      center + const Offset(0, 2),
      14,
      Paint()
        ..color = Colors.black.withAlpha(25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    canvas.drawCircle(center, 14, Paint()..color = Colors.white);
    canvas.drawCircle(center, 7, Paint()..color = color);
  }
}
