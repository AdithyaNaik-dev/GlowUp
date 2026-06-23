import 'package:flutter_tts/flutter_tts.dart';
import 'dart:async';

class VoiceCoachService {
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _muted = false;
  String _lastSpoken = '';
  DateTime? _lastSpokenTime;
  DateTime? _lastTipTime;
  bool _hasGivenSetupHint = false;
  int _tipIndex = 0;
  String _lastExercise = '';

  static final VoiceCoachService _instance = VoiceCoachService._internal();

  factory VoiceCoachService() {
    return _instance;
  }

  VoiceCoachService._internal() {
    _initTts();
  }

  static const List<String> _motivationTips = [
    'Remember to breathe',
    'Keep your core tight',
    'Stay focused',
    'You are doing great',
    'Keep the rhythm',
    'Nice and steady',
    'Control the movement',
    'Almost there, push through',
    'Great energy!',
    'Stay strong',
  ];

  static const Map<String, List<String>> _exerciseSpecificTips = {
    'surprised face': [
      'Raise brows and open mouth together',
      'Maximum facial expression',
      'Feel the intensity',
      'Combine two powerful movements',
      'Great compound movement',
    ],
    'cheek puff': [
      'Push those cheeks out',
      'Keep mouth sealed tight',
      'Hold the pressure',
      'Build cheek muscles',
      'Excellent form',
    ],
    'o face': [
      'Narrow and open at the same time',
      'Perfect O shape',
      'Keep it round and tight',
      'Great control',
      'Your lips are getting stronger',
    ],
    'nose scrunch': [
      'Scrunch that nose high',
      'Feel the crease forming',
      'Tighten nose muscles',
      'Excellent nasalis activation',
      'You\'re building real strength',
    ],
    'smile': [
      'Smile with feeling, not just muscles',
      'Stretch those cheeks wide',
      'Feel the tension in your face',
      'Big smile, big results',
      'Show those pearly whites',
    ],
    'mouth open': [
      'Open wide like a yawn',
      'Feel the stretch in your jaw',
      'Nice and slow',
      'Open and close with control',
      'Your jawline will thank you',
    ],
    'blink': [
      'Fast and forceful',
      'Squeeze those eyes tight',
      'Strengthen your eye area',
      'Quick blinks, strong eyes',
      'Keep it steady',
    ],
    'eyebrow raise': [
      'Raise those brows high',
      'Feel your forehead working',
      'Smooth and controlled',
      'That forehead lift',
      'Higher and higher',
    ],
    'wink': [
      'Perfect wink technique',
      'One eye at a time',
      'Control that eye',
      'Smooth and precise',
      'Your eye muscles are getting stronger',
    ],
    'jumping jacks': [
      'Jump higher',
      'Spread those legs',
      'Explosive energy',
      'Full arm extension',
      'Keep that pace up',
      'Your cardio is improving',
    ],
    'squats': [
      'Go lower',
      'Keep your back straight',
      'Feel the burn',
      'Powerful legs',
      'Push through your heels',
      'Your quads are on fire',
    ],
    'high knees': [
      'Lift those knees high',
      'Fast pace now',
      'Drive those knees up',
      'Keep it explosive',
      'Cardio blast',
    ],
    'pushups': [
      'Nice and low',
      'Control that descent',
      'Strong and steady',
      'Powerful chest',
      'Your strength is building',
    ],
    'plank': [
      'Hold it steady',
      'Keep your body straight',
      'Core is locked in',
      'Great form',
      'You got this',
    ],
  };

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.05);

    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
    });
  }

  bool get isSpeaking => _isSpeaking;

  bool get isMuted => _muted;

  Future<void> toggleMute() async {
    _muted = !_muted;
    if (_muted) {
      await stop();
    }
  }

  void setMuted(bool value) {
    _muted = value;
    if (_muted) stop();
  }

  Future<void> _maybeSpeak(String text) async {
    if (_muted) return;
    await _flutterTts.speak(text);
  }

  Future<void> speakInstruction(String text) async {
    await _flutterTts.stop();
    _lastSpoken = text;
    _lastSpokenTime = DateTime.now();
    await _maybeSpeak(text);
  }

  Future<void> announceExerciseStart({
    required String exerciseName,
    required String voiceInstruction,
    required bool isFace,
    required bool isTimerBased,
    required int targetReps,
    required int targetDuration,
    required bool isFirstExercise,
  }) async {
    _lastExercise = exerciseName.toLowerCase();
    final parts = <String>[];

    if (isFirstExercise && !_hasGivenSetupHint) {
      _hasGivenSetupHint = true;
      parts.add("Let's begin. Place your phone on a stable surface in a well lit area.");
    }

    parts.add(exerciseName);

    if (!isFace) {
      parts.add('Stand about 2 meters from the camera so your full body is visible.');
    }

    parts.add(voiceInstruction);

    if (isTimerBased) {
      parts.add('Hold for $targetDuration seconds. Ready? Go!');
    } else {
      parts.add('Do $targetReps reps. Let\'s go!');
    }

    await speakInstruction(parts.join('. '));
  }

  Future<void> announceRep(int count, int target) async {
    if (_isSpeaking) return;

    String text = '';

    // Varied rep callouts based on progress
    if (count == 1) {
      text = 'One! Let\'s go!';
    } else if (count == target) {
      text = '$count! You crushed it!';
    } else if (count % 5 == 0) {
      if (count == 5) {
        text = 'Five reps! Great start!';
      } else if (count == 10) {
        text = 'Ten! Halfway there!';
      } else if (count >= target * 0.75) {
        text = '$count! Almost done, finish strong!';
      } else {
        text = '$count! Keep that pace!';
      }
    } else if (count % 2 == 0 && count > 1 && count < 5) {
      text = '$count!';
    } else {
      return;
    }

    // Add exercise-specific encouragement
    if (_lastExercise.isNotEmpty) {
      final tips = _exerciseSpecificTips[_lastExercise];
      if (tips != null && tips.isNotEmpty && count % 3 == 0) {
        final tip = tips[_tipIndex % tips.length];
        text += '. $tip';
        _tipIndex++;
      }
    }

    _lastSpoken = text;
    _lastSpokenTime = DateTime.now();
    await _maybeSpeak(text);
  }

  Future<void> announceTimerCountdown(int secondsRemaining) async {
    if (_isSpeaking) return;

    if (secondsRemaining == 30) {
      await _maybeSpeak('Thirty seconds. Stay focused!');
    } else if (secondsRemaining == 15) {
      await _maybeSpeak('Fifteen seconds left. You\'re doing amazing!');
    } else if (secondsRemaining == 10) {
      await _maybeSpeak('Ten seconds');
    } else if (secondsRemaining == 5) {
      await _maybeSpeak('Five');
    } else if (secondsRemaining <= 3 && secondsRemaining > 0) {
      await _maybeSpeak('$secondsRemaining');
    } else if (secondsRemaining == 0) {
      await _maybeSpeak('Time! Great work!');
    }
  }

  Future<void> giveRandomTip() async {
    if (_isSpeaking) return;

    final now = DateTime.now();
    if (_lastTipTime != null && now.difference(_lastTipTime!).inSeconds < 15) {
      return;
    }

    _lastTipTime = now;

    // Prefer exercise-specific tips
    if (_lastExercise.isNotEmpty) {
      final tips = _exerciseSpecificTips[_lastExercise];
      if (tips != null && tips.isNotEmpty) {
        final tip = tips[_tipIndex % tips.length];
        _tipIndex++;
        await _maybeSpeak(tip);
        return;
      }
    }

    // Fall back to general motivation
    final tip = _motivationTips[_tipIndex % _motivationTips.length];
    _tipIndex++;
    await _maybeSpeak(tip);
  }

  Future<void> giveFeedback(String text, {Duration cooldown = const Duration(seconds: 4)}) async {
    if (_isSpeaking) return;

    final now = DateTime.now();
    if (_lastSpoken == text && _lastSpokenTime != null) {
      if (now.difference(_lastSpokenTime!) < cooldown) {
        return;
      }
    }

    _lastSpoken = text;
    _lastSpokenTime = now;
    await _maybeSpeak(text);
  }

  Future<void> announceRest(int seconds, String nextExerciseName) async {
    final restMsg = seconds > 15
      ? 'Great work! Take a breather. $seconds seconds. Next: $nextExerciseName.'
      : 'Rest. $seconds seconds. Get ready for $nextExerciseName.';
    await speakInstruction(restMsg);
  }

  Future<void> announceComplete() async {
    await speakInstruction('Workout complete! Fantastic effort today! You\'re getting stronger and healthier every single day. Keep crushing it!');
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
  }

  void resetSession() {
    _hasGivenSetupHint = false;
    _tipIndex = 0;
    _lastTipTime = null;
    _lastExercise = '';
  }
}
