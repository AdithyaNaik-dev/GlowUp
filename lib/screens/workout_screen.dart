import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:lottie/lottie.dart';
import '../config/theme.dart';
import '../models/exercise.dart';
import '../services/data_service.dart';
import '../services/exercise_rep_counter.dart';
import '../widgets/exercise_camera_tracker.dart';
import '../services/voice_coach_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'workout_complete_screen.dart';

class WorkoutScreen extends StatefulWidget {
  final int day;

  const WorkoutScreen({super.key, required this.day});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
    with TickerProviderStateMixin {
  final DataService _dataService = DataService();
  final VoiceCoachService _voiceCoach = VoiceCoachService();
  late List<Exercise> _exercises;
  late int _restBetween;
  int _currentIndex = 0;
  int _timeRemaining = 0;
  Timer? _timer;
  Timer? _tickTimer;
  bool _isResting = false;
  bool _isPaused = false;
  bool _isStarted = false;
  bool _isExerciseTransitioning = false;

  int _repCount = 0;

  int _exerciseTimerSeconds = 0;
  Timer? _exerciseTimer;

  Timer? _tipTimer;
  bool _isVoiceMuted = false;

  @override
  void initState() {
    super.initState();
    _voiceCoach.resetSession();
    _exercises = _dataService.getExercisesForDayWithReps(widget.day);
    final plan = _dataService.getDayPlan(widget.day);
    _restBetween = plan?.restBetween ?? 15;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tickTimer?.cancel();
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    _voiceCoach.stop();
    super.dispose();
  }

  ExerciseMode _getMode(Exercise ex) => getExerciseMode(ex.name);

  bool _isFace(Exercise ex) => isFaceExercise(ex.name);

  void _startWorkout() {
    setState(() {
      _isStarted = true;
      _isResting = false;
      _isPaused = false;
    });
    _startExercise(_exercises[_currentIndex], isFirst: true);
  }

  void _startExercise(Exercise exercise, {bool isFirst = false}) {
    _repCount = 0;
    _exerciseTimerSeconds = 0;

    final mode = _getMode(exercise);

    if (mode == ExerciseMode.timerBased) {
      _exerciseTimerSeconds = exercise.duration;
      _startExerciseCountdown(exercise);
    }

    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_isPaused && !_isResting) {
        _voiceCoach.giveRandomTip();
      }
    });

    _voiceCoach.announceExerciseStart(
      exerciseName: exercise.name,
      voiceInstruction: exercise.voiceInstruction,
      isFace: _isFace(exercise),
      isTimerBased: mode == ExerciseMode.timerBased,
      targetReps: exercise.reps,
      targetDuration: exercise.duration,
      isFirstExercise: isFirst,
    );

    setState(() {});
  }

  void _startExerciseCountdown(Exercise exercise) {
    _exerciseTimer?.cancel();
    _exerciseTimerSeconds = exercise.duration;

    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        if (_exerciseTimerSeconds > 0) {
          _exerciseTimerSeconds--;
          SystemSound.play(SystemSoundType.click);
          _voiceCoach.announceTimerCountdown(_exerciseTimerSeconds);
        } else {
          timer.cancel();
          _onExerciseComplete();
        }
      });
    });
  }

  void _startRestTimer() {
    _timer?.cancel();
    _timeRemaining = _restBetween;

    _voiceCoach.announceRest(
      _restBetween,
      _currentIndex < _exercises.length
          ? _exercises[_currentIndex].name
          : 'finish',
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_timeRemaining > 0) {
            _timeRemaining--;
            if (_timeRemaining <= 3 && _timeRemaining > 0) {
              SystemSound.play(SystemSoundType.click);
            }
          } else {
            timer.cancel();
            _isResting = false;
            _isPaused = false;
            _startExercise(_exercises[_currentIndex]);
          }
        });
      }
    });
  }

  void _onExerciseComplete() {
    if (_isExerciseTransitioning) return;
    _isExerciseTransitioning = true;
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();

    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isResting = true;
        _isPaused = false;
      });
      _startRestTimer();
    } else {
      _completeWorkout();
    }
    _isExerciseTransitioning = false;
  }

  void _nextExercise() {
    _timer?.cancel();
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    if (_currentIndex < _exercises.length - 1) {
      setState(() {
        _currentIndex++;
        _isResting = true;
        _isPaused = false;
      });
      _startRestTimer();
    } else {
      _completeWorkout();
    }
  }

  Future<void> _toggleVoiceMute() async {
    setState(() {
      _isVoiceMuted = !_isVoiceMuted;
    });
    await _voiceCoach.toggleMute();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _onTrackingSnapshot(TrackingSnapshot snapshot, Exercise exercise) {
    if (!mounted || _isResting) return;

    final mode = _getMode(exercise);
    if (mode == ExerciseMode.timerBased) return;

    final repIncreased = snapshot.repCount > _repCount;

    setState(() {
      _repCount = snapshot.repCount;
    });

    if (repIncreased) {
      SystemSound.play(SystemSoundType.click);
      _voiceCoach.announceRep(snapshot.repCount, exercise.reps);
    }

    final targetReached = snapshot.isHoldExercise
        ? snapshot.holdSeconds >= exercise.duration
        : snapshot.repCount >= exercise.reps;

    if (targetReached) {
      _onExerciseComplete();
    }
  }

  void _completeWorkout() async {
    _timer?.cancel();
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    _voiceCoach.announceComplete();
    await _dataService.completeDay(widget.day);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkoutCompleteScreen(day: widget.day),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout')),
        body: const Center(child: Text('No exercises found for this day.')),
      );
    }

    final exercise = _exercises[_currentIndex];
    return Scaffold(
      backgroundColor: context.appBackground,
      bottomNavigationBar: const BannerAdWidget(),
      appBar: AppBar(
        title: Text('Day ${widget.day}'),
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => _showExitDialog(),
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ),
      body: !_isStarted
          ? _buildStartView(exercise)
          : _isResting
              ? _buildRestView()
              : _buildExerciseView(exercise),
    );
  }

  Widget _buildStartView(Exercise exercise) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _startWorkout,
              child: SizedBox(
                width: 220,
                height: 220,
                child: DotLottieLoader.fromAsset(
                  'assets/animation/start.lottie',
                  frameBuilder: (ctx, dotlottie) {
                    if (dotlottie != null) {
                      return Lottie.memory(
                        dotlottie.animations.values.single,
                        fit: BoxFit.contain,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Day ${widget.day} Workout',
              style: TextStyle(
                color: context.appTextPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_exercises.length} exercises',
              style: TextStyle(color: context.appTextSecondary, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _exercises.length,
                itemBuilder: (context, index) {
                  final ex = _exercises[index];
                  final mode = _getMode(ex);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: context.appCardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.appDivider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.name,
                                style: TextStyle(
                                  color: context.appTextPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                mode == ExerciseMode.timerBased
                                    ? '${ex.duration}s hold'
                                    : '${ex.reps} reps',
                                style: TextStyle(
                                  color: context.appTextHint,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startWorkout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Start Workout',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseView(Exercise exercise) {
    final mode = _getMode(exercise);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 6),
            _buildProgressBar(),
            const SizedBox(height: 10),
            _buildExerciseHeader(exercise, mode),
            const SizedBox(height: 10),
            Expanded(
              child: ExerciseCameraTracker(
                exercise: exercise,
                isPaused: _isPaused,
                onSnapshot: (snapshot) =>
                    _onTrackingSnapshot(snapshot, exercise),
              ),
            ),
            const SizedBox(height: 12),
            _buildStatsCard(exercise, mode),
            const SizedBox(height: 14),
            _buildControls(mode),
            const SizedBox(height: 8),
            _buildNoteSection(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: (_currentIndex + 1) / _exercises.length,
        minHeight: 6,
        backgroundColor: context.isDark
            ? context.appSurface
            : const Color(0xFFFFE0CC),
        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
      ),
    );
  }

  Widget _buildExerciseHeader(Exercise exercise, ExerciseMode mode) {
    final isLiked = _dataService.isExerciseLiked(exercise.id);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            exercise.name,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.appDivider,
              width: 1.5,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              color: context.appTextHint,
              size: 20,
            ),
            onPressed: () => _showExerciseInfo(exercise),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isLiked ? AppColors.primary : context.appDivider,
              width: 1.5,
            ),
          ),
          child: IconButton(
            icon: Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: isLiked ? AppColors.primary : context.appTextHint,
              size: 20,
            ),
            onPressed: () async {
              await _dataService.toggleLikeExercise(exercise.id);
              if (mounted) {
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(isLiked ? 'Removed from liked' : 'Added to liked'),
                    duration: const Duration(milliseconds: 1000),
                  ),
                );
              }
            },
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  void _showExerciseInfo(Exercise exercise) {
    final difficultyColor = exercise.difficulty == 'easy'
        ? Colors.green
        : exercise.difficulty == 'medium'
            ? Colors.orange
            : Colors.red;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                exercise.image,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    exercise.category == 'face'
                        ? Icons.face
                        : Icons.fitness_center,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    exercise.name,
                    style: TextStyle(
                      color: context.appTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: difficultyColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    exercise.difficulty.toUpperCase(),
                    style: TextStyle(
                      color: difficultyColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'How to do it',
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            if (exercise.steps.isNotEmpty)
              ...exercise.steps.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${entry.key + 1}',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: context.appTextPrimary,
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
            else
              Text(
                exercise.description,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Got it!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(Exercise exercise, ExerciseMode mode) {
    final isTimer = mode == ExerciseMode.timerBased;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appCardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (isTimer) ...[
                Text(
                  '$_exerciseTimerSeconds',
                  style: TextStyle(
                    color: _exerciseTimerSeconds <= 5
                        ? AppColors.primaryDark
                        : AppColors.primary,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    's',
                    style: TextStyle(
                      color: context.appTextHint,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  '$_repCount',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    ' / ${exercise.reps}',
                    style: TextStyle(
                      color: context.appTextHint,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isTimer
                ? '${exercise.name} • Hold ${exercise.duration}s'
                : '${exercise.name} • ${exercise.reps} reps',
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
                children: [
                  TextSpan(
                    text: 'Note: ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const TextSpan(
                    text:
                        'AI might not detect movements perfectly. If you have completed the exercise, tap Next. Tapping Next will start the rest timer.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                const Text(
                  'Take a Break',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recover before next exercise',
                  style: TextStyle(
                    color: context.appTextHint,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    height: 280,
                    child: DotLottieLoader.fromAsset(
                      'assets/animation/rest.lottie',
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
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withAlpha(25),
                          AppColors.primary.withAlpha(10),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(40),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$_timeRemaining',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 68,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'seconds',
                          style: TextStyle(
                            color: context.appTextHint,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.appDivider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Up Next',
                        style: TextStyle(
                          color: context.appTextHint,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _exercises[_currentIndex].name,
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                _showExerciseInfo(_exercises[_currentIndex]),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.info_outline_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _timeRemaining += 15;
                          });
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text(
                          '+15 Sec',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.appSurface,
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _timer?.cancel();
                          setState(() {
                            _isResting = false;
                            _isPaused = false;
                          });
                          _startExercise(_exercises[_currentIndex]);
                        },
                        icon: const Icon(Icons.skip_next_rounded),
                        label: const Text(
                          'Skip Rest',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ExerciseMode mode) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: _toggleVoiceMute,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: (_isVoiceMuted
                          ? context.appSurface
                          : AppColors.primary)
                      .withAlpha(20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: (_isVoiceMuted
                              ? context.appDivider
                              : AppColors.primary)
                          .withAlpha(40)),
                ),
                child: Icon(
                  _isVoiceMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                  color: _isVoiceMuted
                      ? context.appTextHint
                      : AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isVoiceMuted ? 'Muted' : 'Voice',
                style: TextStyle(
                  color: context.appTextSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _togglePause,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withAlpha(50),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
        _controlButton(
          Icons.skip_next_rounded,
          'Next',
          AppColors.primary,
          _nextExercise,
        ),
      ],
    );
  }

  Widget _controlButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(40)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: context.appTextSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appCardColor,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quit Workout?',
          style: TextStyle(color: context.appTextPrimary),
        ),
        content: Text(
          'Your progress for this workout will be lost.',
          style: TextStyle(color: context.appTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Continue',
              style: TextStyle(color: context.appTextSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              _voiceCoach.stop();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Quit',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
