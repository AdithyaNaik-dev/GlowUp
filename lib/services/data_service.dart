import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise.dart';
import '../models/day_plan.dart';
import 'notification_service.dart';
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

  bool get hasSeenWorkoutTutorial =>
      _prefs?.getBool('workout_tutorial_seen') ?? false;

  Future<void> setWorkoutTutorialSeen() async {
    await _prefs?.setBool('workout_tutorial_seen', true);
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
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Daily cap: only award points for the first workout of the day
      final previousWorkoutDate = lastWorkoutDate;
      final alreadyWorkedOutToday = previousWorkoutDate == todayStr;

      await _prefs?.setString('last_workout_date', todayStr);

      if (!alreadyWorkedOutToday) {
        // Extended streak multiplier tiers
        final streak = currentStreak;
        double multiplier = 1.0;
        if (streak >= 30) {
          multiplier = 3.0;
        } else if (streak >= 14) {
          multiplier = 2.5;
        } else if (streak >= 7) {
          multiplier = 2.0;
        } else if (streak >= 4) {
          multiplier = 1.5;
        }
        final earnedPoints = (100 * multiplier).round();
        await addPoints(earnedPoints);
      }

      await NotificationService().onWorkoutComplete(
        day: day,
        streak: currentStreak,
      );
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
  int get weeklyPoints => _prefs?.getInt('weekly_points') ?? 0;
  int get monthlyPoints => _prefs?.getInt('monthly_points') ?? 0;

  Future<void> addPoints(int earned) async {
    _resetWeeklyMonthlyIfNeeded();

    await _prefs?.setInt('points', points + earned);
    await _prefs?.setInt('weekly_points', weeklyPoints + earned);
    await _prefs?.setInt('monthly_points', monthlyPoints + earned);
    await _updatePointsInFirestore();
  }

  // --- Weekly / Monthly reset helpers ---

  String _currentWeekStart() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  void _resetWeeklyMonthlyIfNeeded() {
    final storedWeek = _prefs?.getString('week_start') ?? '';
    final currentWeek = _currentWeekStart();
    if (storedWeek != currentWeek) {
      _prefs?.setInt('weekly_points', 0);
      _prefs?.setString('week_start', currentWeek);
    }

    final storedMonth = _prefs?.getString('month_key') ?? '';
    final currentMonth = _currentMonthKey();
    if (storedMonth != currentMonth) {
      _prefs?.setInt('monthly_points', 0);
      _prefs?.setString('month_key', currentMonth);
    }
  }

  // --- Points decay for inactivity (5% per inactive week) ---

  Future<void> applyPointsDecay() async {
    final lastDate = lastWorkoutDate;
    if (lastDate.isEmpty) return;
    try {
      final lastWorkout = DateTime.parse(lastDate);
      final daysSince = DateTime.now().difference(lastWorkout).inDays;
      if (daysSince < 7) return;

      final lastDecay = _prefs?.getString('last_decay_date') ?? '';
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (lastDecay == todayStr) return;

      final weeksInactive = daysSince ~/ 7;
      double factor = 1.0;
      for (int i = 0; i < weeksInactive; i++) {
        factor *= 0.95;
      }
      final decayedPoints = (points * factor).round();
      if (decayedPoints < points) {
        await _prefs?.setInt('points', decayedPoints);
        await _prefs?.setString('last_decay_date', todayStr);
        await _updatePointsInFirestore();
      }
    } catch (_) {}
  }

  String _generateUserId(String email) {
    // Use full email so different domains never collide
    // Firestore doc IDs allow most chars except '/'
    final sanitized = email.toLowerCase().trim().replaceAll('/', '_');
    return sanitized.isEmpty ? 'user' : sanitized;
  }

  Future<void> syncToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String displayName = userName;
    if (displayName.trim().isEmpty) displayName = user.displayName ?? '';
    if (displayName.trim().isEmpty) displayName = user.email?.split('@').first ?? 'User';

    final userEmail = (user.email ?? '').toLowerCase().trim();
    if (userEmail.isEmpty) return;

    // Capture local state BEFORE any overwrites to detect fresh install
    final localPoints = points;
    final localStreak = currentStreak;
    final localBestStreak = bestStreak;
    final localCompletedDays = completedDays;
    final localCurrentDay = currentDay;
    final localTotalWorkouts = totalWorkoutsCompleted;
    final localLastWorkoutDate = lastWorkoutDate;
    final localLikedExercises = likedExerciseIds;

    // ── RULE: email is the sole identity key ──
    // Same email  → find & update that document
    // New email   → create a brand-new document

    DocumentSnapshot? docSnap;
    DocumentReference? docRef;
    String userId = '';

    // 1. Query by email — the one and only lookup
    final query = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: userEmail)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      docSnap = query.docs.first;
      userId = docSnap.id;
      docRef = docSnap.reference;
    }

    // 2. Not found → this email has never been seen, create a new doc
    if (docSnap == null) {
      userId = _generateUserId(userEmail);
      docRef = FirebaseFirestore.instance.collection('users').doc(userId);
    }

    // Cache the doc ID for this session (fast-path for _updatePoints etc.)
    await _prefs?.setString('firestore_user_id', userId);

    if (docSnap == null || !docSnap.exists) {
      // ── New email → new document ──
      _resetWeeklyMonthlyIfNeeded();
      final data = <String, dynamic>{
        'firebaseUid': user.uid,
        'userId': userId,
        'displayName': displayName,
        'email': userEmail,
        'points': localPoints,
        'weeklyPoints': weeklyPoints,
        'monthlyPoints': monthlyPoints,
        'weekStart': _currentWeekStart(),
        'monthKey': _currentMonthKey(),
        'streak': localStreak,
        'bestStreak': localBestStreak,
        'totalWorkouts': localTotalWorkouts,
        'currentDay': localCurrentDay,
        'completedDays': localCompletedDays.map((e) => e.toString()).toList(),
        'lastWorkoutDate': localLastWorkoutDate,
        'likedExercises': localLikedExercises.toList(),
        'support': {
          'email': 'glowup.officialapp@gmail.com',
          'userId': userId,
          'userEmail': userEmail,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'lastActive': FieldValue.serverTimestamp(),
      };
      if ((user.photoURL ?? '').isNotEmpty) {
        data['photoUrl'] = user.photoURL!;
      }
      await docRef!.set(data);
    } else {
      // ── Same email → update existing document ──
      final data = docSnap.data() as Map<String, dynamic>;
      var firestorePoints = data['points'] as int? ?? 0;
      final firestoreStreak = data['streak'] as int? ?? 0;
      final firestoreBestStreak = data['bestStreak'] as int? ?? 0;
      final firestoreDisplayName = data['displayName'] as String? ?? '';
      final firestoreUserId = data['userId'] as String? ?? userId;
      final firestoreTotalWorkouts = data['totalWorkouts'] as int? ?? 0;
      final firestoreCurrentDay = data['currentDay'] as int? ?? 1;
      final firestoreLastWorkoutDate = data['lastWorkoutDate'] as String? ?? '';
      final firestoreCompletedDays = (data['completedDays'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final firestoreLikedExercises = (data['likedExercises'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final firestoreWeekStart = data['weekStart'] as String? ?? '';
      final firestoreMonthKey = data['monthKey'] as String? ?? '';
      var firestoreWeeklyPoints = data['weeklyPoints'] as int? ?? 0;
      var firestoreMonthlyPoints = data['monthlyPoints'] as int? ?? 0;

      // Reset stale weekly/monthly from Firestore
      if (firestoreWeekStart != _currentWeekStart()) firestoreWeeklyPoints = 0;
      if (firestoreMonthKey != _currentMonthKey()) firestoreMonthlyPoints = 0;

      // Apply points decay for inactivity (5% per inactive week)
      final decaySource = firestoreLastWorkoutDate.isNotEmpty
          ? firestoreLastWorkoutDate
          : localLastWorkoutDate;
      if (decaySource.isNotEmpty) {
        try {
          final daysSince =
              DateTime.now().difference(DateTime.parse(decaySource)).inDays;
          if (daysSince >= 7) {
            double factor = 1.0;
            for (int i = 0; i < daysSince ~/ 7; i++) {
              factor *= 0.95;
            }
            firestorePoints = (firestorePoints * factor).round();
          }
        } catch (_) {}
      }

      final isFreshInstall =
          localPoints == 0 && localCompletedDays.isEmpty && localCurrentDay == 1;

      _resetWeeklyMonthlyIfNeeded();
      final localWeekly = weeklyPoints;
      final localMonthly = monthlyPoints;

      final mergedPoints = localPoints > firestorePoints ? localPoints : firestorePoints;
      final mergedStreak = localStreak > firestoreStreak ? localStreak : firestoreStreak;
      final mergedBestStreak = localBestStreak > firestoreBestStreak ? localBestStreak : firestoreBestStreak;
      final mergedDisplayName = displayName.isNotEmpty ? displayName : firestoreDisplayName;
      final mergedTotalWorkouts = localTotalWorkouts > firestoreTotalWorkouts ? localTotalWorkouts : firestoreTotalWorkouts;
      final mergedCurrentDay = localCurrentDay > firestoreCurrentDay ? localCurrentDay : firestoreCurrentDay;
      final mergedWeekly = localWeekly > firestoreWeeklyPoints ? localWeekly : firestoreWeeklyPoints;
      final mergedMonthly = localMonthly > firestoreMonthlyPoints ? localMonthly : firestoreMonthlyPoints;

      final mergedCompletedDaysStr = <String>{
        ...localCompletedDays.map((e) => e.toString()),
        ...firestoreCompletedDays,
      };

      final mergedLastWorkoutDate =
          _moreRecentDate(localLastWorkoutDate, firestoreLastWorkoutDate);

      final mergedLikedExercises = <String>{
        ...localLikedExercises,
        ...firestoreLikedExercises,
      };

      final updateData = <String, dynamic>{
        'firebaseUid': user.uid,
        'userId': firestoreUserId,
        'displayName': mergedDisplayName,
        'email': userEmail,
        'streak': mergedStreak,
        'bestStreak': mergedBestStreak,
        'points': mergedPoints,
        'weeklyPoints': mergedWeekly,
        'monthlyPoints': mergedMonthly,
        'weekStart': _currentWeekStart(),
        'monthKey': _currentMonthKey(),
        'totalWorkouts': mergedTotalWorkouts,
        'currentDay': mergedCurrentDay,
        'completedDays': mergedCompletedDaysStr.toList(),
        'lastWorkoutDate': mergedLastWorkoutDate,
        'likedExercises': mergedLikedExercises.toList(),
        'support': {
          'email': 'glowup.officialapp@gmail.com',
          'userId': firestoreUserId,
          'userEmail': userEmail,
        },
        'lastActive': FieldValue.serverTimestamp(),
      };
      if ((user.photoURL ?? '').isNotEmpty) {
        updateData['photoUrl'] = user.photoURL!;
      }
      await docRef!.update(updateData);

      // ── Pull merged data into local SharedPreferences ──
      await _prefs?.setInt('points', mergedPoints);
      await _prefs?.setInt('weekly_points', mergedWeekly);
      await _prefs?.setInt('monthly_points', mergedMonthly);
      await _prefs?.setString('week_start', _currentWeekStart());
      await _prefs?.setString('month_key', _currentMonthKey());
      await _prefs?.setInt('current_streak', mergedStreak);
      await _prefs?.setInt('best_streak', mergedBestStreak);
      await _prefs?.setString('user_name', mergedDisplayName);
      await _prefs?.setInt('total_workouts_completed', mergedTotalWorkouts);
      await _prefs?.setInt('current_day', mergedCurrentDay);
      await _prefs?.setString('last_workout_date', mergedLastWorkoutDate);
      await _prefs?.setStringList('completed_days', mergedCompletedDaysStr.toList());
      await _prefs?.setStringList('liked_exercises', mergedLikedExercises.toList());

      // On fresh install with existing data, skip setup screens
      if (isFreshInstall && firestorePoints > 0) {
        await _prefs?.setBool('onboarding_complete', true);
        await _prefs?.setBool('health_metrics_complete', true);
        await _prefs?.setBool('personalization_complete', true);
        await _prefs?.setBool('auth_complete', true);
      }
    }
  }

  String _moreRecentDate(String a, String b) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    try {
      return DateTime.parse(a).isAfter(DateTime.parse(b)) ? a : b;
    } catch (_) {
      return a;
    }
  }

  Future<void> _updatePointsInFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docId = _prefs?.getString('firestore_user_id') ?? '';
    if (docId.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(docId).set({
      'points': points,
      'weeklyPoints': weeklyPoints,
      'monthlyPoints': monthlyPoints,
      'weekStart': _currentWeekStart(),
      'monthKey': _currentMonthKey(),
      'streak': currentStreak,
      'bestStreak': bestStreak,
      'totalWorkouts': totalWorkoutsCompleted,
      'currentDay': currentDay,
      'completedDays': completedDays.map((e) => e.toString()).toList(),
      'lastWorkoutDate': lastWorkoutDate,
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

  String get userName => _prefs?.getString('user_name') ?? '';

  Future<void> setUserName(String name) async {
    await _prefs?.setString('user_name', name);
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
    await _prefs?.remove('firestore_user_id');

    // Clear all user-specific data so the next account starts fresh
    await _prefs?.remove('points');
    await _prefs?.remove('current_streak');
    await _prefs?.remove('best_streak');
    await _prefs?.remove('current_day');
    await _prefs?.remove('completed_days');
    await _prefs?.remove('total_workouts_completed');
    await _prefs?.remove('last_workout_date');
    await _prefs?.remove('liked_exercises');
    await _prefs?.remove('user_name');
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

    final docId = _prefs?.getString('firestore_user_id') ?? '';
    if (docId.isEmpty) return;

    await FirebaseFirestore.instance.collection('users').doc(docId).set({
      'likedExercises': likedExerciseIds.toList(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteFirestoreData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docId = _prefs?.getString('firestore_user_id') ?? '';
      if (docId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .delete();
    } catch (_) {}
  }

  Future<void> clearAllData() async {
    await deleteFirestoreData();
    await _prefs?.clear();
  }
}
