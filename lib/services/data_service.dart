import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise.dart';
import '../models/day_plan.dart';
import 'workout_generator_service.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  List<Exercise> _faceExercises = [];
  List<Exercise> _bodyExercises = [];
  List<DayPlan> _dailyPlan = [];
  SharedPreferences? _prefs;

  List<Exercise> get faceExercises => _faceExercises;
  List<Exercise> get bodyExercises => _bodyExercises;
  List<DayPlan> get dailyPlan => _dailyPlan;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadExerciseData();
  }

  Future<void> _loadExerciseData() async {
    final String jsonString =
        await rootBundle.loadString('assets/data/exercise_plan.json');
    final Map<String, dynamic> data = json.decode(jsonString);

    _faceExercises = (data['face_exercises'] as List)
        .map((e) => Exercise.fromJson(e))
        .toList();

    _bodyExercises = (data['body_exercises'] as List)
        .map((e) => Exercise.fromJson(e))
        .toList();

    _dailyPlan = (data['daily_plan'] as List)
        .map((e) => DayPlan.fromJson(e))
        .toList();
  }

  Exercise? getExerciseById(String id) {
    final allExercises = [..._faceExercises, ..._bodyExercises];
    try {
      return allExercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  DayPlan? getDayPlan(int day) {
    try {
      return _dailyPlan.firstWhere((d) => d.day == day);
    } catch (_) {
      // For post-30 days, generate a plan
      if (day > 30 && _prefs != null) {
        return _generateDayPlan(day);
      }
      return null;
    }
  }

  DayPlan? _generateDayPlan(int day) {
    if (_prefs == null) return null;
    final generator = WorkoutGeneratorService();
    return generator.generateForDay(
      day,
      prefs: _prefs!,
      faceExercises: _faceExercises,
      bodyExercises: _bodyExercises,
    );
  }

  List<Exercise> getExercisesForDay(int day) {
    final plan = getDayPlan(day);
    if (plan == null) return [];

    final exercises = <Exercise>[];
    for (final id in plan.faceExerciseIds) {
      final ex = getExerciseById(id);
      if (ex != null) exercises.add(ex);
    }
    for (final id in plan.bodyExerciseIds) {
      final ex = getExerciseById(id);
      if (ex != null) exercises.add(ex);
    }
    return exercises;
  }

  // --- Persistence ---

  bool get hasCompletedOnboarding =>
      _prefs?.getBool('onboarding_complete') ?? false;

  Future<void> setOnboardingComplete() async {
    await _prefs?.setBool('onboarding_complete', true);
  }

  int get currentDay => _prefs?.getInt('current_day') ?? 1;

  Future<void> setCurrentDay(int day) async {
    await _prefs?.setInt('current_day', day);
  }

  Set<int> get completedDays {
    final list = _prefs?.getStringList('completed_days') ?? [];
    return list.map((e) => int.parse(e)).toSet();
  }

  Future<void> completeDay(int day) async {
    final completed = completedDays;
    if (!completed.contains(day)) {
      completed.add(day);
      await _prefs?.setStringList(
          'completed_days', completed.map((e) => e.toString()).toList());

      await _updateStreak(day);

      // Always advance to next day (for both 1-30 and post-30)
      await setCurrentDay(day + 1);

      // Track total workouts completed
      final totalWorkouts = (_prefs?.getInt('total_workouts_completed') ?? 0) + 1;
      await _prefs?.setInt('total_workouts_completed', totalWorkouts);

      // Store last workout date for date-based streak tracking
      final today = DateTime.now();
      await _prefs?.setString(
        'last_workout_date',
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
      );

      // Calculate and add points
      final streakBeforeCompletion = currentStreak;
      double multiplier = 1.0;
      if (streakBeforeCompletion >= 4 && streakBeforeCompletion <= 6) {
        multiplier = 1.5;
      } else if (streakBeforeCompletion >= 7) {
        multiplier = 2.0;
      }
      int earnedPoints = (100 * multiplier).round();
      await addPoints(earnedPoints);
    }
  }

  Future<void> _updateStreak(int completedDay) async {
    int streak = 0;

    if (completedDay <= 30) {
      // For days 1-30, count consecutive completed days from the end
      final completed = completedDays;
      for (int day = completedDay; day >= 1; day--) {
        if (completed.contains(day)) {
          streak++;
        } else {
          break;
        }
      }
    } else {
      // For post-30 days, use date-based streak from last_workout_date
      final lastWorkoutStr = _prefs?.getString('last_workout_date');
      if (lastWorkoutStr != null) {
        try {
          final lastWorkoutDate = DateTime.parse(lastWorkoutStr);
          final today = DateTime.now();
          final yesterday = today.subtract(const Duration(days: 1));
          final lastWorkoutDayOnly = DateTime(
            lastWorkoutDate.year,
            lastWorkoutDate.month,
            lastWorkoutDate.day,
          );
          final yesterdayDayOnly =
              DateTime(yesterday.year, yesterday.month, yesterday.day);

          // If last workout was yesterday, increment streak
          if (lastWorkoutDayOnly == yesterdayDayOnly) {
            streak = (currentStreak) + 1;
          } else {
            // If last workout was today, keep streak
            streak = currentStreak;
          }
        } catch (_) {
          streak = 1;
        }
      } else {
        streak = 1;
      }
    }

    await _prefs?.setInt('current_streak', streak);
    if (streak > bestStreak) {
      await _prefs?.setInt('best_streak', streak);
    }
  }

  int get currentStreak => _prefs?.getInt('current_streak') ?? 0;
  int get bestStreak => _prefs?.getInt('best_streak') ?? 0;
  int get points => _prefs?.getInt('points') ?? 0;

  Future<void> addPoints(int earned) async {
    int p = points + earned;
    await _prefs?.setInt('points', p);
    await _updatePointsInFirestore();
  }

  Future<void> syncToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnap = await docRef.get();
    
    String name = user.displayName ?? '';
    if (name.trim().isEmpty) {
      name = user.email?.split('@').first ?? 'User';
    }

    if (!docSnap.exists) {
      await docRef.set({
        'name': name,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'points': points,
        'streak': currentStreak,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final data = docSnap.data() as Map<String, dynamic>;
      int firestoreStreak = data['streak'] ?? 0;
      int firestorePoints = data['points'] ?? 0;
      
      if (data['lastActive'] != null) {
        final lastActiveDate = (data['lastActive'] as Timestamp).toDate();
        final now = DateTime.now();
        final lastActiveDay = DateTime(lastActiveDate.year, lastActiveDate.month, lastActiveDate.day);
        final currentDay = DateTime(now.year, now.month, now.day);
        
        final difference = currentDay.difference(lastActiveDay).inDays;
        
        if (difference == 1) {
          firestoreStreak++;
        } else if (difference > 1) {
          firestoreStreak = 0;
        }
      } else {
        firestoreStreak = 0;
      }

      final mergedStreak = currentStreak > firestoreStreak ? currentStreak : firestoreStreak;
      
      int maxPoints = points > firestorePoints ? points : firestorePoints;
      
      await docRef.set({
        'name': name,
        'email': user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'streak': mergedStreak,
        'points': maxPoints,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      await _prefs?.setInt('current_streak', mergedStreak);
      if (firestorePoints > points) {
        await _prefs?.setInt('points', firestorePoints);
      }
      if (mergedStreak > bestStreak) {
        await _prefs?.setInt('best_streak', mergedStreak);
      }
    }
  }

  Future<void> _updatePointsInFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'points': points,
      'streak': currentStreak,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  double get progressPercent => completedDays.length / 30.0;

  int get totalWorkoutsCompleted =>
      _prefs?.getInt('total_workouts_completed') ?? 0;

  bool get hasCompletedChallenge => completedDays.containsAll(
      List.generate(30, (i) => i + 1));

  bool get isInPostChallengeMode => currentDay > 30;

  String get lastWorkoutDate =>
      _prefs?.getString('last_workout_date') ?? '';

  // --- Fitness Level ---

  String get fitnessLevel => _prefs?.getString('fitness_level') ?? 'beginner';

  Future<void> setFitnessLevel(String level) async {
    await _prefs?.setString('fitness_level', level);
  }

  // --- Health Metrics ---

  double get weight => _prefs?.getDouble('weight') ?? 0.0;

  Future<void> setWeight(double weight) async {
    await _prefs?.setDouble('weight', weight);
  }

  double get height => _prefs?.getDouble('height') ?? 0.0;

  Future<void> setHeight(double height) async {
    await _prefs?.setDouble('height', height);
  }

  double calculateBMI(double weight, double height) {
    if (height <= 0) return 0;
    return weight / (height * height);
  }

  double get bmi => calculateBMI(weight, height);

  int get age => _prefs?.getInt('age') ?? 0;

  Future<void> setAge(int age) async {
    await _prefs?.setInt('age', age);
  }

  String get fitnessGoal => _prefs?.getString('fitness_goal') ?? 'lean_build';

  Future<void> setFitnessGoal(String goal) async {
    await _prefs?.setString('fitness_goal', goal);
  }

  bool get hasCompletedHealthMetrics =>
      _prefs?.getBool('health_metrics_complete') ?? false;

  Future<void> setHealthMetricsComplete() async {
    await _prefs?.setBool('health_metrics_complete', true);
  }

  bool get hasCompletedPersonalization =>
      _prefs?.getBool('personalization_complete') ?? false;

  Future<void> setPersonalizationComplete() async {
    await _prefs?.setBool('personalization_complete', true);
  }

  // --- Auth state ---

  bool get hasSkippedAuth => _prefs?.getBool('auth_skipped') ?? false;

  Future<void> setAuthSkipped() async {
    await _prefs?.setBool('auth_skipped', true);
  }

  bool get hasCompletedAuth => _prefs?.getBool('auth_complete') ?? false;

  Future<void> setAuthComplete() async {
    await _prefs?.setBool('auth_complete', true);
  }

  Future<void> clearAuthState() async {
    await _prefs?.remove('auth_skipped');
    await _prefs?.remove('auth_complete');
  }

  int get baseReps {
    switch (fitnessLevel) {
      case 'beginner':
        return 10;
      case 'medium':
        return 15;
      case 'advanced':
        return 20;
      default:
        return 10;
    }
  }

  List<Exercise> getExercisesForDayWithReps(int day) {
    final exercises = getExercisesForDay(day);
    final reps = baseReps;
    return exercises.map((ex) => Exercise(
      id: ex.id,
      name: ex.name,
      description: ex.description,
      duration: ex.duration,
      reps: reps,
      image: ex.image,
      category: ex.category,
      difficulty: ex.difficulty,
      voiceInstruction: ex.voiceInstruction,
    )).toList();
  }

  // --- Liked Exercises ---

  Set<String> get likedExerciseIds {
    final list = _prefs?.getStringList('liked_exercises') ?? [];
    return list.toSet();
  }

  bool isExerciseLiked(String exerciseId) => likedExerciseIds.contains(exerciseId);

  Future<void> toggleLikeExercise(String exerciseId) async {
    final liked = likedExerciseIds;
    if (liked.contains(exerciseId)) {
      liked.remove(exerciseId);
    } else {
      liked.add(exerciseId);
    }
    await _prefs?.setStringList('liked_exercises', liked.toList());
    await _syncLikesToFirestore();
  }

  Future<void> _syncLikesToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'likedExercises': likedExerciseIds.toList(),
    }, SetOptions(merge: true));
  }

  Future<void> clearAllData() async {
    await _prefs?.clear();
  }
}
