import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/theme.dart';
import 'config/theme_notifier.dart';
import 'services/data_service.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/health_metrics_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/personalization_setup_screen.dart';
import 'screens/main_shell.dart';

final ThemeNotifier themeNotifier = ThemeNotifier();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await DataService().init();
  await AdService().init();
  if (AuthService().isSignedIn) {
    try {
      await DataService().syncToFirestore();
    } catch (_) {
      // Sync may fail due to permissions or network issues; continue startup
    }
  }
  runApp(const GlowUpApp());
}

class GlowUpApp extends StatefulWidget {
  const GlowUpApp({super.key});

  @override
  State<GlowUpApp> createState() => _GlowUpAppState();
}

class _GlowUpAppState extends State<GlowUpApp> {
  late final Widget _home;

  @override
  void initState() {
    super.initState();
    final dataService = DataService();
    final hasCompletedOnboarding = dataService.hasCompletedOnboarding;
    final hasCompletedHealthMetrics = dataService.hasCompletedHealthMetrics;
    final hasCompletedPersonalization = dataService.hasCompletedPersonalization;
    final hasAuthDone =
        dataService.hasCompletedAuth || dataService.hasSkippedAuth || AuthService().isSignedIn;

    Widget nextScreen;
    if (!hasCompletedOnboarding) {
      nextScreen = const OnboardingScreen();
    } else if (!hasCompletedHealthMetrics) {
      nextScreen = const HealthMetricsScreen();
    } else if (!hasCompletedPersonalization) {
      nextScreen = const PersonalizationSetupScreen();
    } else if (!hasAuthDone) {
      nextScreen = const AuthScreen();
    } else {
      nextScreen = const MainShell();
    }
    _home = SplashScreen(nextScreen: nextScreen);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: 'GlowUp – 30 Day Challenge',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeNotifier.themeMode,
          home: _home,
        );
      },
    );
  }
}
