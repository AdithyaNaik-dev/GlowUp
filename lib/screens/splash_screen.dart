import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final Future<Widget> initFuture;

  const SplashScreen({super.key, required this.initFuture});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _textFade;

  bool _minTimeElapsed = false;
  Widget? _nextScreen;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _controller.forward();
    });

    // Minimum splash so the animation plays
    Future.delayed(const Duration(milliseconds: 1800), () {
      _minTimeElapsed = true;
      _tryNavigate();
    });

    // Wait for background init to finish
    widget.initFuture.then((screen) {
      _nextScreen = screen;
      _tryNavigate();
    });
  }

  void _tryNavigate() {
    if (_navigated || !_minTimeElapsed || _nextScreen == null || !mounted) {
      return;
    }
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => _nextScreen!,
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.asset(
                'assets/images/logo.jpeg',
                width: 160,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _textFade,
              child: Column(
                children: [
                  Text(
                    'GlowUp',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '30 Day Challenge',
                    style: TextStyle(
                      color: const Color(0xFF757575),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
