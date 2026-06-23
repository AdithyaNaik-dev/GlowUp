import 'dart:math';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/day_plan.dart';
import '../models/exercise.dart';

class WorkoutGeneratorService {
  static final WorkoutGeneratorService _instance =
      WorkoutGeneratorService._internal();

  factory WorkoutGeneratorService() => _instance;

  WorkoutGeneratorService._internal();

  DayPlan generateForDay(
    int day, {
    required SharedPreferences prefs,
    required List<Exercise> faceExercises,
    required List<Exercise> bodyExercises,
  }) {
    final likedIds = _getLikedExerciseIds(prefs);
    final totalWorkouts = prefs.getInt('total_workouts_completed') ?? 0;
    final history = _getRecentPlanHistory(prefs);

    return _generate(
      day,
      likedIds,
      totalWorkouts,
      history,
      faceExercises,
      bodyExercises,
    );
  }

  DayPlan _generate(
    int day,
    Set<String> likedIds,
    int totalWorkouts,
    Map<String, List<String>> history,
    List<Exercise> faceExercises,
    List<Exercise> bodyExercises,
  ) {
    // Deterministic seed from calendar date
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final rng = Random(seed);

    // Determine tier
    final tier = _getTier(totalWorkouts);

    // Select exercises with weights
    final faceIds = _weightedSelect(
      faceExercises,
      5,
      likedIds,
      history['face'] ?? [],
      tier,
      rng,
    );

    final bodyIds = _weightedSelect(
      bodyExercises,
      5,
      likedIds,
      history['body'] ?? [],
      tier,
      rng,
    );

    // Guarantee at least 1 liked exercise
    _guaranteeLiked(faceIds, faceExercises, likedIds, rng);
    _guaranteeLiked(bodyIds, bodyExercises, likedIds, rng);

    // Guarantee warm-up exercises at position 0
    _guaranteeWarmup(faceIds, 'face_04');
    _guaranteeWarmup(bodyIds, 'body_01');

    return DayPlan(
      day: day,
      phase: tier.phaseName,
      faceExerciseIds: faceIds,
      bodyExerciseIds: bodyIds,
      restBetween: tier.restBetween,
    );
  }

  List<String> _weightedSelect(
    List<Exercise> pool,
    int count,
    Set<String> likedIds,
    List<String> recentExercises,
    _Tier tier,
    Random rng,
  ) {
    final weights = <String, double>{};

    for (final ex in pool) {
      double w = 1.0;

      // Liked bonus
      if (likedIds.contains(ex.id)) {
        w += 2.0;
      }

      // Recency penalty
      if (recentExercises.isNotEmpty && recentExercises[0] == ex.id) {
        w *= 0.1;
      }
      if (recentExercises.length > 1 && recentExercises[1] == ex.id) {
        w *= 0.4;
      }

      // Difficulty gating
      if (tier == _Tier.steady && ex.difficulty == 'hard') {
        w *= 0.5;
      }
      if (tier == _Tier.elite && ex.difficulty == 'easy') {
        w *= 0.7;
      }

      weights[ex.id] = w;
    }

    // Weighted selection without replacement
    final selected = <String>[];
    final remaining = Map<String, double>.from(weights);

    for (int i = 0; i < count && remaining.isNotEmpty; i++) {
      final totalWeight = remaining.values.reduce((a, b) => a + b);
      var roll = rng.nextDouble() * totalWeight;
      String? chosen;

      for (final entry in remaining.entries) {
        roll -= entry.value;
        if (roll <= 0) {
          chosen = entry.key;
          break;
        }
      }

      chosen ??= remaining.keys.last;
      selected.add(chosen);
      remaining.remove(chosen);
    }

    return selected;
  }

  void _guaranteeLiked(
    List<String> selected,
    List<Exercise> pool,
    Set<String> likedIds,
    Random rng,
  ) {
    if (likedIds.isEmpty) return;

    final selectedLiked = selected.where((id) => likedIds.contains(id));
    if (selectedLiked.isNotEmpty) return;

    // No liked exercises in selection, swap lowest with highest-weight liked
    final likedPool = pool.where((ex) => likedIds.contains(ex.id)).toList();
    if (likedPool.isEmpty) return;

    final likedToAdd = likedPool[rng.nextInt(likedPool.length)];
    selected[0] = likedToAdd.id;
  }

  void _guaranteeWarmup(List<String> selected, String warmupId) {
    if (selected.contains(warmupId)) {
      selected.remove(warmupId);
    } else {
      selected.removeLast();
    }
    selected.insert(0, warmupId);
  }

  _Tier _getTier(int totalWorkouts) {
    if (totalWorkouts <= 40) {
      return _Tier.steady;
    } else if (totalWorkouts <= 60) {
      return _Tier.push;
    } else {
      return _Tier.elite;
    }
  }

  Set<String> _getLikedExerciseIds(SharedPreferences prefs) {
    final list = prefs.getStringList('liked_exercises') ?? [];
    return list.toSet();
  }

  Map<String, List<String>> _getRecentPlanHistory(SharedPreferences prefs) {
    final historyJson = prefs.getString('generated_plan_history') ?? '{}';
    try {
      final decoded = jsonDecode(historyJson) as Map<String, dynamic>;
      return {
        'face': List<String>.from(decoded['face'] ?? []),
        'body': List<String>.from(decoded['body'] ?? []),
      };
    } catch (_) {
      return {'face': [], 'body': []};
    }
  }

  Future<void> saveToHistory(
    SharedPreferences prefs,
    DayPlan plan,
  ) async {
    final history = {
      'face': plan.faceExerciseIds,
      'body': plan.bodyExerciseIds,
    };
    await prefs.setString('generated_plan_history', jsonEncode(history));
  }
}

enum _Tier {
  steady,
  push,
  elite,
}

extension _TierExtension on _Tier {
  String get phaseName {
    switch (this) {
      case _Tier.steady:
        return 'steady';
      case _Tier.push:
        return 'push';
      case _Tier.elite:
        return 'elite';
    }
  }

  int get restBetween {
    switch (this) {
      case _Tier.steady:
        return 12;
      case _Tier.push:
        return 10;
      case _Tier.elite:
        return 8;
    }
  }
}
