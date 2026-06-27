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
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  // "Take your position" countdown before every exercise
  bool _isCountingDown = false;
  int _countdownSeconds = 3;
  Timer? _countdownTimer;

  // Two-stage stuck rescue: if no rep is counted for a while, nudge + loosen
  // detection (stage 1), then give voice guidance pointing to Next / ⓘ (stage 2).
  Timer? _stuckTimer;
  DateTime? _lastRepWallTime;
  bool _stuckStage1Fired = false;
  bool _stuckStage2Fired = false;
  int _sensitivityBoost = 0;
  bool _trackingStarted = false; // true once the rep counter enters tracking phase

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceCoach.resetSession();
    _exercises = _dataService.getExercisesForDayWithReps(widget.day);
    final plan = _dataService.getDayPlan(widget.day);
    _restBetween = plan?.restBetween ?? 15;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _tickTimer?.cancel();
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    _stuckTimer?.cancel();
    _countdownTimer?.cancel();
    _voiceCoach.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // User switched to another app — pause everything so they can resume.
      if (_isStarted && !_isPaused) {
        setState(() => _isPaused = true);
        _voiceCoach.stop();
      }
    }
  }

  ExerciseMode _getMode(Exercise ex) => getExerciseMode(ex.name);

  bool _isFace(Exercise ex) => isFaceExercise(ex.name);

  void _startWorkout() {
    if (!_dataService.hasSeenWorkoutTutorial) {
      _showWorkoutTutorial(() {
        _dataService.setWorkoutTutorialSeen();
        _beginWorkout();
      });
      return;
    }
    _beginWorkout();
  }

  void _beginWorkout() {
    setState(() {
      _isStarted = true;
      _isResting = false;
      _isPaused = false;
    });
    _startExercise(_exercises[_currentIndex], isFirst: true);
  }

  void _showWorkoutTutorial(VoidCallback onDone) {
    final steps = <_TutorialStep>[
      _TutorialStep(
        icon: Icons.phone_android_rounded,
        title: 'Setup',
        body: 'For face exercises, just hold your phone and look at the camera. For body exercises, lean your phone against a wall and step back so your full body is visible.',
      ),
      _TutorialStep(
        icon: Icons.pan_tool_rounded,
        title: 'Stay still',
        body: 'Once the app detects you, it will say "Stay still." Hold your natural position for a moment while it learns your baseline.',
      ),
      _TutorialStep(
        icon: Icons.play_circle_rounded,
        title: 'Go!',
        body: 'When you hear "Go!" start the exercise. The AI counts your reps automatically. Even small movements count!',
      ),
      _TutorialStep(
        icon: Icons.skip_next_rounded,
        title: 'Stuck? No worries',
        body: 'If the AI can\'t detect your movement, just tap Next to move on. Tap the ⓘ button anytime to learn how to do an exercise.',
      ),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WorkoutTutorialSheet(steps: steps, onDone: onDone),
    );
  }

  void _startExercise(Exercise exercise, {bool isFirst = false}) {
    _repCount = 0;
    _exerciseTimerSeconds = 0;
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    _stuckTimer?.cancel();
    _countdownTimer?.cancel();
    _stuckStage1Fired = false;
    _stuckStage2Fired = false;
    _trackingStarted = false;

    final mode = _getMode(exercise);

    // Voice: exercise name + instruction, then "Take your position"
    _voiceCoach.announceExerciseStart(
      exerciseName: exercise.name,
      voiceInstruction: exercise.voiceInstruction,
      isFace: _isFace(exercise),
      isTimerBased: mode == ExerciseMode.timerBased,
      targetReps: exercise.reps,
      targetDuration: exercise.duration,
      isFirstExercise: isFirst,
    );

    // Start the 3-2-1 countdown. During this time the camera is already
    // running — MediaPipe detects the user and calibrates their baseline.
    setState(() {
      _isCountingDown = true;
      _countdownSeconds = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPaused) return;

      setState(() {
        if (_countdownSeconds > 1) {
          _countdownSeconds--;
          SystemSound.play(SystemSoundType.click);
        } else {
          // Countdown done — start the exercise
          timer.cancel();
          _isCountingDown = false;
          _voiceCoach.announceGo();
          _onCountdownComplete(exercise);
        }
      });
    });
  }

  void _onCountdownComplete(Exercise exercise) {
    final mode = _getMode(exercise);

    // Start timer for hold exercises
    if (mode == ExerciseMode.timerBased) {
      _exerciseTimerSeconds = exercise.duration;
      _startExerciseCountdown(exercise);
    }

    // Random tips
    _tipTimer?.cancel();
    _tipTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!_isPaused && !_isResting) {
        _voiceCoach.giveRandomTip();
      }
    });

    // For AI-tracked, the stuck timer is armed when tracking phase starts
    // (handled in _onTrackingSnapshot). For timer-based, no stuck timer needed.
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
    _stuckTimer?.cancel();
    _countdownTimer?.cancel();
    _isCountingDown = false;

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
    _stuckTimer?.cancel();
    _countdownTimer?.cancel();
    _isCountingDown = false;
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

  void _previousExercise() {
    if (_currentIndex <= 0) return;
    _timer?.cancel();
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    _stuckTimer?.cancel();
    _countdownTimer?.cancel();
    _isCountingDown = false;
    setState(() {
      _currentIndex--;
      _isResting = true;
      _isPaused = false;
    });
    _startRestTimer();
  }

  void _restartExercise() {
    _exerciseTimer?.cancel();
    _tipTimer?.cancel();
    _stuckTimer?.cancel();
    _countdownTimer?.cancel();
    _isCountingDown = false;
    _voiceCoach.stop();
    _startExercise(_exercises[_currentIndex]);
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

  // Runs once per second while an AI-tracked exercise is active. If the user
  // has gone too long without a counted rep, escalate help in two stages.
  void _checkStuck() {
    if (!mounted || _isPaused || _isResting) return;
    final last = _lastRepWallTime;
    if (last == null) return;
    final stuckSecs = DateTime.now().difference(last).inSeconds;

    if (stuckSecs >= 20 && !_stuckStage2Fired) {
      _stuckStage2Fired = true;
      // Voice only — points to the always-visible Next and ⓘ buttons.
      _voiceCoach.announceDetectionTrouble();
    } else if (stuckSecs >= 10 && !_stuckStage1Fired) {
      _stuckStage1Fired = true;
      setState(() => _sensitivityBoost++); // loosen detection one notch
      _voiceCoach.nudgeBiggerMovement();
    }
  }

  void _onTrackingSnapshot(TrackingSnapshot snapshot, Exercise exercise) {
    if (!mounted || _isResting) return;

    final mode = _getMode(exercise);
    if (mode == ExerciseMode.timerBased) return;

    // ── Phase transitions: voice cues at the right moments ──
    if (snapshot.phase == TrackingPhase.calibrating && !_trackingStarted) {
      _voiceCoach.announceStayStill();
    }
    if (snapshot.justStartedTracking && !_trackingStarted) {
      _trackingStarted = true;
      _voiceCoach.announceGo();
      // NOW arm the stuck-rescue clock — user is actually exercising.
      _lastRepWallTime = DateTime.now();
      _stuckTimer?.cancel();
      _stuckTimer =
          Timer.periodic(const Duration(seconds: 1), (_) => _checkStuck());
    }

    final repIncreased = snapshot.repCount > _repCount;

    setState(() {
      _repCount = snapshot.repCount;
    });

    if (repIncreased) {
      _lastRepWallTime = DateTime.now();
      _stuckStage1Fired = false;
      _stuckStage2Fired = false;
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
    _stuckTimer?.cancel();
    _countdownTimer?.cancel();
    _isCountingDown = false;
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ExerciseCameraTracker(
                      exercise: exercise,
                      isPaused: _isPaused,
                      sensitivityBoost: _sensitivityBoost,
                      onSnapshot: (snapshot) =>
                          _onTrackingSnapshot(snapshot, exercise),
                    ),
                  ),
                  if (_isCountingDown)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Ready',
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$_countdownSeconds',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 72,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
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
        _controlButton(
          Icons.skip_previous_rounded,
          'Back',
          _currentIndex > 0 ? context.appTextSecondary : context.appTextHint,
          _currentIndex > 0 ? _previousExercise : null,
        ),
        _controlButton(
          Icons.replay_rounded,
          'Restart',
          context.appTextSecondary,
          _restartExercise,
        ),
        // Center pause/play button
        GestureDetector(
          onTap: _togglePause,
          child: Container(
            width: 64,
            height: 64,
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
              size: 32,
            ),
          ),
        ),
        _controlButton(
          Icons.skip_next_rounded,
          'Next',
          context.appTextSecondary,
          _nextExercise,
        ),
        _controlButton(
          _isVoiceMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          _isVoiceMuted ? 'Muted' : 'Voice',
          _isVoiceMuted ? context.appTextHint : context.appTextSecondary,
          _toggleVoiceMute,
        ),
      ],
    );
  }

  Widget _controlButton(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
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

// ═══════════════════════════════════════════════════════════════════
//  First-time workout tutorial (shown once, before the first workout)
// ═══════════════════════════════════════════════════════════════════

class _TutorialStep {
  final IconData icon;
  final String title;
  final String body;
  const _TutorialStep({required this.icon, required this.title, required this.body});
}

class _WorkoutTutorialSheet extends StatefulWidget {
  final List<_TutorialStep> steps;
  final VoidCallback onDone;
  const _WorkoutTutorialSheet({required this.steps, required this.onDone});

  @override
  State<_WorkoutTutorialSheet> createState() => _WorkoutTutorialSheetState();
}

class _WorkoutTutorialSheetState extends State<_WorkoutTutorialSheet> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_current];
    final isLast = _current == widget.steps.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Text(
            'How It Works',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          // Step icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(step.icon, color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 16),
          // Step title
          Text(
            step.title,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          // Step body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              step.body,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appTextSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.steps.length, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _current ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _current
                      ? AppColors.primary
                      : AppColors.primary.withAlpha(40),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          // Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                if (isLast) {
                  Navigator.pop(context);
                  widget.onDone();
                } else {
                  setState(() => _current++);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                isLast ? "Let's Go!" : 'Next',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
