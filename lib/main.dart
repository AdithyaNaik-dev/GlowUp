import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/theme.dart';
import 'config/theme_notifier.dart';
import 'services/data_service.dart';
import 'services/auth_service.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
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
  runApp(const GlowUpApp());
}

Future<Widget> _loadRemainingServices() async {
  await Future.wait([
    NotificationService().init(),
    AdService().init(),
    if (AuthService().isSignedIn) _syncUser(),
  ]);

  await NotificationService().checkStreakBroken(
    previousStreak: DataService().currentStreak,
    lastWorkoutDate: DataService().lastWorkoutDate,
  );

  final ds = DataService();
  final authDone =
      ds.hasCompletedAuth || ds.hasSkippedAuth || AuthService().isSignedIn;

  if (!ds.hasCompletedOnboarding) return const OnboardingScreen();
  if (!ds.hasCompletedHealthMetrics) return const HealthMetricsScreen();
  if (!ds.hasCompletedPersonalization) return const PersonalizationSetupScreen();
  if (!authDone) return const AuthScreen();
  return const MainShell();
}

Future<void> _syncUser() async {
  try {
    await DataService().syncToFirestore();
    await DataService().applyPointsDecay();
  } catch (_) {}
}

class GlowUpApp extends StatefulWidget {
  const GlowUpApp({super.key});

  @override
  State<GlowUpApp> createState() => _GlowUpAppState();
}

class _GlowUpAppState extends State<GlowUpApp> {
  late final Future<Widget> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _loadRemainingServices();
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
          home: SplashScreen(initFuture: _initFuture),
        );
      },
    );
  }
}
