import 'dart:math' as math;

import 'mediapipe_bridge_service.dart';

// ─── Exercise mode classification ───
enum ExerciseMode { aiTracked, timerBased, manual }

ExerciseMode getExerciseMode(String name) {
  final n = name.toLowerCase();
  if (n == 'plank' || n == 'wall sit' || n == 'dynamic plank' ||
      n.contains('mewing') || n.contains('tongue suction') ||
      n == 'neck extensions' || n == 'neck lift' || n == 'jaw clench hold' ||
      n == 'star crunch' || n == 'tuck crunches' || n == 'rear lunges') {
    return ExerciseMode.timerBased;
  }
  return ExerciseMode.aiTracked;
}

bool isFaceExercise(String name) {
  final n = name.toLowerCase();
  return n.contains('mouth') || n.contains('smile') || n.contains('blink') ||
      n.contains('eyebrow') || n.contains('lip') || n.contains('wink') ||
      n.contains('jaw') || n.contains('chin') || n.contains('fish') ||
      n.contains('tongue') || n.contains('cheek') || n.contains('eye') ||
      n.contains('neck') || n.contains('mewing') || n.contains('nose') ||
      n.contains('surprised') || n == 'o face';
}

class TrackingSnapshot {
  final String currentExercise;
  final int repCount;
  final bool isRepInProgress;
  final String previousState;
  final String statusText;
  final bool isHoldExercise;
  final int holdSeconds;
  final String? guidanceHint;

  const TrackingSnapshot({
    required this.currentExercise,
    required this.repCount,
    required this.isRepInProgress,
    required this.previousState,
    required this.statusText,
    required this.isHoldExercise,
    required this.holdSeconds,
    this.guidanceHint,
  });
}

// ─── Smoothing helper ───
class _SmoothedValue {
  double _value = 0;
  bool _initialized = false;

  double update(double raw, {double alpha = 0.4}) {
    if (!_initialized) {
      _value = raw;
      _initialized = true;
      return _value;
    }
    _value = (1 - alpha) * _value + alpha * raw;
    return _value;
  }

  double get value => _value;
  void reset() { _initialized = false; _value = 0; }
}

// ─── State machine ───
enum _RepPhase { idle, active }

class ExerciseRepCounter {
  String currentExercise = '';
  int repCount = 0;
  _RepPhase _phase = _RepPhase.idle;
  String previousState = 'idle';

  String statusText = 'Get ready';
  bool isHoldExercise = false;
  Duration _holdDuration = Duration.zero;
  String? guidanceHint;

  DateTime? _lastTimestamp;
  DateTime? _lastRepTime;
  bool _leftSideTriggered = false;
  bool _rightSideTriggered = false;
  int _missingFrames = 0;
  int _framesSinceStart = 0;

  final Map<String, _SmoothedValue> _smoothed = {};

  bool _calibrated = false;
  final Map<String, double> _baseline = {};
  DateTime? _exerciseStartTime;

  List<LandmarkPoint>? _lastValidFace;
  List<LandmarkPoint>? _lastValidPose;
  int _faceHoldFrames = 0;
  int _poseHoldFrames = 0;

  bool get isRepInProgress => _phase == _RepPhase.active;

  double _getSmoothed(String key, double raw) {
    _smoothed.putIfAbsent(key, () => _SmoothedValue());
    return _smoothed[key]!.update(raw);
  }

  void resetForExercise(String exerciseName, {String difficulty = 'medium'}) {
    currentExercise = exerciseName;
    repCount = 0;
    _phase = _RepPhase.idle;
    previousState = 'idle';
    statusText = 'Get ready';
    isHoldExercise = _isHold(exerciseName);
    _holdDuration = Duration.zero;
    guidanceHint = null;
    _lastTimestamp = null;
    _lastRepTime = null;
    _leftSideTriggered = false;
    _rightSideTriggered = false;
    _missingFrames = 0;
    _framesSinceStart = 0;
    _smoothed.clear();
    _calibrated = false;
    _baseline.clear();
    _exerciseStartTime = null;
    _lastValidFace = null;
    _lastValidPose = null;
    _faceHoldFrames = 0;
    _poseHoldFrames = 0;
  }

  TrackingSnapshot update({
    required String exerciseName,
    required List<LandmarkPoint> poseLandmarks,
    required List<LandmarkPoint> faceLandmarks,
    required DateTime timestamp,
    String difficulty = 'medium',
  }) {
    if (currentExercise != exerciseName) {
      resetForExercise(exerciseName, difficulty: difficulty);
    }

    _exerciseStartTime ??= timestamp;
    _framesSinceStart++;

    final dt = _lastTimestamp == null
        ? Duration.zero
        : timestamp.difference(_lastTimestamp!);
    _lastTimestamp = timestamp;

    final normalized = exerciseName.toLowerCase();

    // ── Frame buffer: hold last valid landmarks for 8 frames ──
    if (faceLandmarks.isNotEmpty) {
      _lastValidFace = faceLandmarks;
      _faceHoldFrames = 0;
    } else if (_lastValidFace != null && _faceHoldFrames < 8) {
      faceLandmarks = _lastValidFace!;
      _faceHoldFrames++;
    }

    if (poseLandmarks.isNotEmpty) {
      _lastValidPose = poseLandmarks;
      _poseHoldFrames = 0;
    } else if (_lastValidPose != null && _poseHoldFrames < 8) {
      poseLandmarks = _lastValidPose!;
      _poseHoldFrames++;
    }

    if (isFaceExercise(normalized)) {
      _updateFaceExercise(normalized, faceLandmarks, dt);
    } else {
      _updateBodyExercise(normalized, poseLandmarks, dt);
    }

    return TrackingSnapshot(
      currentExercise: currentExercise,
      repCount: repCount,
      isRepInProgress: isRepInProgress,
      previousState: previousState,
      statusText: statusText,
      isHoldExercise: isHoldExercise,
      holdSeconds: _holdDuration.inSeconds,
      guidanceHint: guidanceHint,
    );
  }

  // ════════════════════════════════════════════
  //  FACE EXERCISES
  // ════════════════════════════════════════════
  void _updateFaceExercise(
    String exercise,
    List<LandmarkPoint> landmarks,
    Duration dt,
  ) {
    guidanceHint = null;

    if (landmarks.isEmpty) {
      _missingFrames++;
      if (_missingFrames > 20) {
        statusText = 'Face not visible';
        guidanceHint = 'Position your face in the camera';
      } else {
        statusText = 'Tracking...';
      }
      return;
    }
    _missingFrames = 0;

    final byId = {for (final point in landmarks) point.id: point};

    double? dist(int a, int b) {
      final p1 = byId[a];
      final p2 = byId[b];
      if (p1 == null || p2 == null) return null;
      return _dist(p1.x, p1.y, p2.x, p2.y);
    }

    final elapsed = _exerciseStartTime != null
        ? DateTime.now().difference(_exerciseStartTime!).inMilliseconds
        : 0;
    final inCalibration = elapsed < 3000;

    switch (exercise) {
      case 'jaw open-close':
      case 'jaw open close':
      case 'mouth open':
        final raw = dist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('mouth_v', raw);

        if (inCalibration) {
          _baseline['mouth'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['mouth'] ?? 0.015;
        final open = v > base + 0.007;
        final close = v < base + 0.003;
        _countWithStateMachine(active: open, reset: close);
        break;

      case 'smile':
        final raw = dist(61, 291);
        if (raw == null) return;
        final v = _getSmoothed('smile_w', raw);

        if (inCalibration) {
          _baseline['smile'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['smile'] ?? 0.25;
        final wide = v > base + 0.015;
        final neutral = v < base + 0.006;
        _countWithStateMachine(active: wide, reset: neutral);
        break;

      case 'blink':
        final leftH = dist(159, 145);
        final rightH = dist(386, 374);
        if (leftH == null || rightH == null) return;
        final avgEar = (leftH + rightH) / 2;
        final v = _getSmoothed('blink', avgEar);

        if (inCalibration) {
          _baseline['blink'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['blink'] ?? 0.025;
        final closed = v < base * 0.65;
        final open = v > base * 0.75;
        _countWithStateMachine(active: closed, reset: open);
        break;

      case 'eyebrow raise':
        final leftBrow = byId[70];
        final leftEye = byId[159];
        final rightBrow = byId[300];
        final rightEye = byId[386];
        if (leftBrow == null || leftEye == null || rightBrow == null || rightEye == null) return;

        final rawDist = ((leftBrow.y - leftEye.y).abs() + (rightBrow.y - rightEye.y).abs()) / 2;
        final v = _getSmoothed('eyebrow', rawDist);

        if (inCalibration) {
          _baseline['eyebrow'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['eyebrow'] ?? 0.04;
        final raised = v > base + 0.004;
        final neutral = v < base + 0.002;
        _countWithStateMachine(active: raised, reset: neutral);
        break;

      case 'lip pucker':
        final raw = dist(61, 291);
        if (raw == null) return;
        final v = _getSmoothed('pucker', raw);

        if (inCalibration) {
          _baseline['pucker'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['pucker'] ?? 0.25;
        final puckered = v < base - 0.012;
        final neutral = v > base - 0.005;
        _countWithStateMachine(active: puckered, reset: neutral);
        break;

      case 'left wink':
        final leftH = dist(159, 145);
        final rightH = dist(386, 374);
        if (leftH == null || rightH == null) return;
        final lv = _getSmoothed('lwink_l', leftH);
        final rv = _getSmoothed('lwink_r', rightH);

        if (inCalibration) {
          _baseline['lwink'] = lv;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['lwink'] ?? 0.025;
        final leftClosed = lv < base * 0.65 && rv > base * 0.45;
        final open = lv > base * 0.75;
        _countWithStateMachine(active: leftClosed, reset: open);
        break;

      case 'right wink':
        final leftH = dist(159, 145);
        final rightH = dist(386, 374);
        if (leftH == null || rightH == null) return;
        final lv = _getSmoothed('rwink_l', leftH);
        final rv = _getSmoothed('rwink_r', rightH);

        if (inCalibration) {
          _baseline['rwink'] = rv;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['rwink'] ?? 0.025;
        final rightClosed = rv < base * 0.65 && lv > base * 0.45;
        final open = rv > base * 0.75;
        _countWithStateMachine(active: rightClosed, reset: open);
        break;

      case 'jaw shift':
        final chin = byId[152];
        final nose = byId[1];
        if (chin == null || nose == null) return;
        final rawShift = (chin.x - nose.x);
        final v = _getSmoothed('jawshift', rawShift);

        if (inCalibration) {
          _baseline['jawshift'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final base = _baseline['jawshift'] ?? 0;
        final shifted = (v - base).abs() > 0.009;
        final centered = (v - base).abs() < 0.005;
        _countWithStateMachine(active: shifted, reset: centered);
        break;

      case 'chin lift':
      case 'neck raise':
        final raw = dist(152, 1);
        if (raw == null) return;
        final v = _getSmoothed('chinlift', raw);

        if (inCalibration) {
          _baseline['chinlift'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final baseChin = _baseline['chinlift'] ?? 0.15;
        final up = v > baseChin + 0.008;
        final neutralChin = v < baseChin + 0.003;
        _countWithStateMachine(active: up, reset: neutralChin);
        break;

      case 'fish face':
        final raw = dist(234, 454);
        if (raw == null) return;
        final v = _getSmoothed('fishface', raw);

        if (inCalibration) {
          _baseline['fishface'] = v;
          statusText = 'Calibrating...';
          return;
        }

        final baseFish = _baseline['fishface'] ?? 0.35;
        final contracted = v < baseFish - 0.012;
        final released = v > baseFish - 0.005;
        _countWithStateMachine(active: contracted, reset: released);
        break;

      case 'jaw resistance':
        final raw = dist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('jawres', raw);
        final openJaw = v > 0.025;
        final closeJaw = v < 0.018;
        _countWithStateMachine(active: openJaw, reset: closeJaw);
        break;

      case 'cheek lift':
        final leftCheek = byId[205];
        final rightCheek = byId[425];
        final leftEye = byId[159];
        final rightEye = byId[386];
        if (leftCheek == null || rightCheek == null || leftEye == null || rightEye == null) return;

        final rawCheek = ((leftEye.y - leftCheek.y) + (rightEye.y - rightCheek.y)) / 2;
        final vCheek = _getSmoothed('cheeklift', rawCheek);

        if (inCalibration) {
          _baseline['cheeklift'] = vCheek;
          statusText = 'Calibrating...';
          return;
        }

        final baseCheek = _baseline['cheeklift'] ?? 0.10;
        final lifted = vCheek < baseCheek - 0.004;
        final relaxCheek = vCheek > baseCheek - 0.002;
        _countWithStateMachine(active: lifted, reset: relaxCheek);
        break;

      case 'eye widening':
        final leftEyeOpen = dist(159, 145);
        final rightEyeOpen = dist(386, 374);
        if (leftEyeOpen == null || rightEyeOpen == null) return;
        final avg = _getSmoothed('eyewiden', (leftEyeOpen + rightEyeOpen) / 2);

        if (inCalibration) {
          _baseline['eyewiden'] = avg;
          statusText = 'Calibrating...';
          return;
        }

        final baseEye = _baseline['eyewiden'] ?? 0.022;
        final widen = avg > baseEye + 0.004;
        final normal = avg < baseEye + 0.002;
        _countWithStateMachine(active: widen, reset: normal);
        break;

      case 'mewing':
      case 'tongue suction (mewing)':
      case 'tongue suction':
        final raw = dist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('mewing', raw);
        final good = v < 0.028;
        statusText = good ? 'Good form' : 'Close your mouth';
        _updateHoldTracking(exercise, dt, good);
        break;

      case 'neck extensions':
      case 'neck lift':
      case 'jaw clench hold':
        statusText = 'Hold position';
        _updateHoldTracking(exercise, dt, true);
        break;

      case 'surprised face':
        final eyebrowLeft = byId[70];
        final eyeLeftTop = byId[159];
        final eyebrowRight = byId[300];
        final eyeRightTop = byId[386];
        final rawMouth = dist(13, 14);

        if (eyebrowLeft == null || eyeLeftTop == null || eyebrowRight == null || eyeRightTop == null || rawMouth == null) return;

        final rawBrow = ((eyebrowLeft.y - eyeLeftTop.y).abs() + (eyebrowRight.y - eyeRightTop.y).abs()) / 2;
        final vBrow = _getSmoothed('surprised_brow', rawBrow);
        final vMouth = _getSmoothed('surprised_mouth', rawMouth);

        if (inCalibration) {
          _baseline['surprised_brow'] = vBrow;
          _baseline['surprised_mouth'] = vMouth;
          statusText = 'Calibrating...';
          return;
        }

        final baseBrow = _baseline['surprised_brow'] ?? 0.04;
        final baseMouth = _baseline['surprised_mouth'] ?? 0.015;
        final browsRaised = vBrow > baseBrow + 0.002;
        final mouthOpen = vMouth > baseMouth + 0.004;
        final active = browsRaised && mouthOpen;
        final reset = vBrow < baseBrow + 0.001 && vMouth < baseMouth + 0.002;
        _countWithStateMachine(active: active, reset: reset);
        break;

      case 'cheek puff':
        final cheekL = byId[50];
        final cheekR = byId[280];
        final noseCenter = byId[1];
        final rawMouth2 = dist(13, 14);

        if (cheekL == null || cheekR == null || noseCenter == null || rawMouth2 == null) return;

        final cheekWidth = _getSmoothed('cheek_puff_width', _dist(cheekL.x, cheekL.y, cheekR.x, cheekR.y));
        final mouthClosed = _getSmoothed('cheek_puff_mouth', rawMouth2);

        if (inCalibration) {
          _baseline['cheek_puff'] = cheekWidth;
          _baseline['cheek_puff_mouth'] = mouthClosed;
          statusText = 'Calibrating...';
          return;
        }

        final basePuff = _baseline['cheek_puff'] ?? 0.35;
        final baseMouthClose = _baseline['cheek_puff_mouth'] ?? 0.015;
        final puffed = cheekWidth > basePuff + 0.008;
        final released = cheekWidth < basePuff + 0.003;
        final closed = mouthClosed < baseMouthClose + 0.008;
        _countWithStateMachine(active: puffed && closed, reset: released);
        break;

      case 'o face':
        final rawMouthW = dist(61, 291);
        final rawMouthV = dist(13, 14);

        if (rawMouthW == null || rawMouthV == null) return;

        final vWidth = _getSmoothed('oface_width', rawMouthW);
        final vHeight = _getSmoothed('oface_height', rawMouthV);

        if (inCalibration) {
          _baseline['oface_width'] = vWidth;
          _baseline['oface_height'] = vHeight;
          statusText = 'Calibrating...';
          return;
        }

        final baseWidth = _baseline['oface_width'] ?? 0.25;
        final baseHeight = _baseline['oface_height'] ?? 0.015;
        final narrowed = vWidth < baseWidth - 0.005;
        final open = vHeight > baseHeight + 0.004;
        final released = vWidth > baseWidth - 0.002;
        _countWithStateMachine(active: narrowed && open, reset: released);
        break;

      case 'nose scrunch':
        final noseBridge = byId[6];
        final noseTip = byId[1];
        final noseWingL = byId[48];
        final noseWingR = byId[278];

        if (noseBridge == null || noseTip == null || noseWingL == null || noseWingR == null) return;

        final rawBridgeToTip = dist(6, 1);
        final rawWingSpread = _dist(noseWingL.x, noseWingL.y, noseWingR.x, noseWingR.y);

        if (rawBridgeToTip == null) return;

        final vBridge = _getSmoothed('nose_scrunch_bridge', rawBridgeToTip);
        final vWings = _getSmoothed('nose_scrunch_wings', rawWingSpread);

        if (inCalibration) {
          _baseline['nose_scrunch'] = vBridge;
          _baseline['nose_wings'] = vWings;
          statusText = 'Calibrating...';
          return;
        }

        final baseBridgeDist = _baseline['nose_scrunch'] ?? 0.15;
        final baseWingDist = _baseline['nose_wings'] ?? 0.06;
        final scrunched = vBridge < baseBridgeDist - 0.004;
        final wingsNarrowed = vWings < baseWingDist - 0.003;
        final released = vBridge > baseBridgeDist - 0.002;
        _countWithStateMachine(active: scrunched || wingsNarrowed, reset: released);
        break;

      default:
        statusText = 'Tracking';
    }
  }

  // ════════════════════════════════════════════
  //  BODY EXERCISES (Front-view optimized)
  // ════════════════════════════════════════════
  void _updateBodyExercise(
    String exercise,
    List<LandmarkPoint> landmarks,
    Duration dt,
  ) {
    guidanceHint = null;

    if (landmarks.isEmpty) {
      _missingFrames++;
      if (_missingFrames > 20) {
        statusText = 'Body not visible';
        guidanceHint = 'Step back so your full body is visible';
      } else {
        statusText = 'Tracking...';
      }
      return;
    }

    final visible = landmarks.where((l) => l.visibility >= 0.3).toList();
    final visibleRatio = visible.length / landmarks.length;

    if (visibleRatio < 0.3) {
      _missingFrames++;
      statusText = 'Move into frame';
      guidanceHint = 'Step back — full body not visible';
      return;
    }
    _missingFrames = 0;

    final byId = {for (final point in visible) point.id: point};

    final hasUpperBody = byId.containsKey(11) && byId.containsKey(12);
    final hasLowerBody = byId.containsKey(27) || byId.containsKey(28);

    if (!hasUpperBody) {
      guidanceHint = 'Move back — shoulders not visible';
    } else if (!hasLowerBody && !exercise.contains('push')) {
      guidanceHint = 'Step back — legs not visible';
    }

    switch (exercise) {
      case 'jumping jacks':
        final leftWrist = byId[15];
        final rightWrist = byId[16];
        final leftShoulder = byId[11];
        final rightShoulder = byId[12];

        if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) {
          statusText = 'Show full arms';
          return;
        }

        // Either arm above shoulder counts
        final armsUp = leftWrist.y < leftShoulder.y + 0.02 || rightWrist.y < rightShoulder.y + 0.02;
        final armsDown = leftWrist.y > leftShoulder.y + 0.05 && rightWrist.y > rightShoulder.y + 0.05;

        _countWithStateMachine(active: armsUp, reset: armsDown);
        break;

      case 'squats':
        final leftKnee = _safeAngle(byId, 23, 25, 27);
        final rightKnee = _safeAngle(byId, 24, 26, 28);

        if (leftKnee != null || rightKnee != null) {
          final knee = _getSmoothed('squat_knee',
              leftKnee != null && rightKnee != null
                  ? (leftKnee + rightKnee) / 2
                  : (leftKnee ?? rightKnee!));

          final down = knee < 150;
          final up = knee > 160;
          _countWithStateMachine(active: down, reset: up, peakHint: 'Go lower');
        } else {
          final hip = byId[23] ?? byId[24];
          if (hip != null) {
            final v = _getSmoothed('squat_hip', hip.y);
            if (!_calibrated && _framesSinceStart > 10) {
              _baseline['squat_hip'] = v;
              _calibrated = true;
            }
            final base = _baseline['squat_hip'] ?? v;
            final dropped = v > base + 0.03;
            final risen = v < base + 0.012;
            _countWithStateMachine(active: dropped, reset: risen, peakHint: 'Go lower');
          }
        }
        break;

      case 'high knees':
        final leftKnee = byId[25];
        final rightKnee = byId[26];
        final leftHip = byId[23];
        final rightHip = byId[24];

        if (leftKnee != null && leftHip != null) {
          final leftUp = leftKnee.y < leftHip.y + 0.06;
          if (leftUp && !_leftSideTriggered) {
            if (_canCountRep()) {
              repCount++;
              _lastRepTime = DateTime.now();
              _leftSideTriggered = true;
              statusText = 'Good!';
            }
          }
          if (!leftUp) _leftSideTriggered = false;
        }

        if (rightKnee != null && rightHip != null) {
          final rightUp = rightKnee.y < rightHip.y + 0.06;
          if (rightUp && !_rightSideTriggered) {
            if (_canCountRep()) {
              repCount++;
              _lastRepTime = DateTime.now();
              _rightSideTriggered = true;
              statusText = 'Good!';
            }
          }
          if (!rightUp) _rightSideTriggered = false;
        }

        if (!_leftSideTriggered && !_rightSideTriggered) {
          statusText = 'Lift knees higher';
        }
        break;

      case 'arm raises':
      case 'front raise':
        final leftWrist = byId[15];
        final rightWrist = byId[16];
        final leftShoulder = byId[11];
        final rightShoulder = byId[12];

        if (leftWrist == null || rightWrist == null || leftShoulder == null || rightShoulder == null) return;

        final armsUp = leftWrist.y < leftShoulder.y + 0.02 && rightWrist.y < rightShoulder.y + 0.02;
        final armsDown = leftWrist.y > leftShoulder.y + 0.06 && rightWrist.y > rightShoulder.y + 0.06;

        _countWithStateMachine(active: armsUp, reset: armsDown, peakHint: 'Raise higher');
        break;

      case 'pushups':
      case 'push-ups':
        final shoulder = byId[11] ?? byId[12];
        if (shoulder != null) {
          final v = _getSmoothed('pushup_y', shoulder.y);

          if (!_calibrated && _framesSinceStart > 10) {
            _baseline['pushup_y'] = v;
            _calibrated = true;
            statusText = 'Start push-ups';
            return;
          }

          final base = _baseline['pushup_y'] ?? v;
          final down = v > base + 0.025;
          final up = v < base + 0.01;
          _countWithStateMachine(active: down, reset: up, peakHint: 'Go lower');
        } else {
          final left = _safeAngle(byId, 11, 13, 15);
          final right = _safeAngle(byId, 12, 14, 16);
          if (left != null || right != null) {
            final elbow = _getSmoothed('pushup_elbow',
                left != null && right != null ? (left + right) / 2 : (left ?? right!));
            final down = elbow < 130;
            final up = elbow > 150;
            _countWithStateMachine(active: down, reset: up, peakHint: 'Go lower');
          }
        }
        break;

      case 'standing knee raises':
      case 'mountain climbers':
        final leftKnee = byId[25];
        final rightKnee = byId[26];
        final leftHip = byId[23];
        final rightHip = byId[24];

        if (leftKnee != null && leftHip != null) {
          final leftUp = leftKnee.y < leftHip.y + 0.04;
          if (leftUp && !_leftSideTriggered) _leftSideTriggered = true;
          if (!leftUp) _leftSideTriggered = false;
        }

        if (rightKnee != null && rightHip != null) {
          final rightUp = rightKnee.y < rightHip.y + 0.04;
          if (rightUp && !_rightSideTriggered) _rightSideTriggered = true;
          if (!rightUp) _rightSideTriggered = false;
        }

        if (_leftSideTriggered && _rightSideTriggered) {
          if (_canCountRep()) {
            repCount++;
            _lastRepTime = DateTime.now();
            statusText = 'Good!';
          }
          _leftSideTriggered = false;
          _rightSideTriggered = false;
        } else {
          statusText = 'Drive knees up';
        }
        break;

      case 'side steps':
        final leftAnkle = byId[27];
        final rightAnkle = byId[28];
        final leftHip = byId[23];
        final rightHip = byId[24];

        if (leftAnkle == null || rightAnkle == null || leftHip == null || rightHip == null) return;

        final legSpread = _getSmoothed('sidestep', _dist(leftAnkle.x, leftAnkle.y, rightAnkle.x, rightAnkle.y));
        final hipW = _dist(leftHip.x, leftHip.y, rightHip.x, rightHip.y);

        final wide = legSpread > hipW * 1.6;
        final closed = legSpread < hipW * 1.2;
        _countWithStateMachine(active: wide, reset: closed);
        break;

      case 'burpees':
        final shoulder = byId[11] ?? byId[12];
        if (shoulder != null) {
          final v = _getSmoothed('burpee_y', shoulder.y);
          if (!_calibrated && _framesSinceStart > 10) {
            _baseline['burpee_y'] = v;
            _calibrated = true;
          }
          final base = _baseline['burpee_y'] ?? v;
          final down = v > base + 0.05;
          final up = v < base + 0.015;
          _countWithStateMachine(active: down, reset: up);
        }
        break;

      case 'plank':
      case 'wall sit':
        final shoulder = byId[11];
        final hip = byId[23];
        if (shoulder != null && hip != null) {
          final good = exercise == 'plank'
              ? _isPlankOk(byId)
              : _isWallSitOk(byId);
          statusText = good ? 'Good form' : 'Adjust posture';
          _updateHoldTracking(exercise, dt, good);
        } else {
          statusText = 'Hold position';
          _updateHoldTracking(exercise, dt, true);
        }
        break;

      case 'dynamic plank':
      case 'star crunch':
      case 'tuck crunches':
      case 'rear lunges':
        statusText = 'Keep going';
        _updateHoldTracking(exercise, dt, true);
        break;

      default:
        statusText = 'Tracking';
    }
  }

  // ─── Core state machine with cooldown + hysteresis ───
  void _countWithStateMachine({
    required bool active,
    required bool reset,
    String peakHint = 'Keep going',
    String resetHint = 'Good rep!',
  }) {
    if (active && _phase == _RepPhase.idle) {
      _phase = _RepPhase.active;
      previousState = 'active';
      statusText = peakHint;
      return;
    }

    if (reset && _phase == _RepPhase.active) {
      if (_canCountRep()) {
        repCount++;
        _lastRepTime = DateTime.now();
        statusText = resetHint;
      }
      _phase = _RepPhase.idle;
      previousState = 'idle';
      return;
    }

    if (_phase == _RepPhase.idle) {
      statusText = 'Keep going';
    }
  }

  bool _canCountRep() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!).inMilliseconds > 200;
  }

  void _updateHoldTracking(String exercise, Duration dt, bool goodForm) {
    if (goodForm && dt.inMilliseconds > 0) {
      _holdDuration += dt;
    }
  }

  bool _isHold(String exercise) {
    final n = exercise.toLowerCase();
    return n == 'plank' || n == 'wall sit' || n == 'dynamic plank' ||
        n.contains('mewing') || n.contains('tongue suction') ||
        n == 'neck extensions' || n == 'neck lift' || n == 'jaw clench hold' ||
        n == 'star crunch' || n == 'tuck crunches' || n == 'rear lunges';
  }

  bool _isPlankOk(Map<int, LandmarkPoint> byId) {
    final shoulder = byId[11];
    final hip = byId[23];
    final ankle = byId[27];
    if (shoulder == null || hip == null) return true;
    if (ankle == null) return true;
    final angle = _angleFromPoints(shoulder, hip, ankle);
    return angle > 120;
  }

  bool _isWallSitOk(Map<int, LandmarkPoint> byId) {
    final knee = _safeAngle(byId, 23, 25, 27);
    if (knee == null) return true;
    return knee > 50 && knee < 140;
  }

  double? _safeAngle(Map<int, LandmarkPoint> byId, int a, int b, int c) {
    final p1 = byId[a];
    final p2 = byId[b];
    final p3 = byId[c];
    if (p1 == null || p2 == null || p3 == null) return null;
    return _angleFromPoints(p1, p2, p3);
  }

  double _angleFromPoints(LandmarkPoint a, LandmarkPoint b, LandmarkPoint c) {
    final abx = a.x - b.x;
    final aby = a.y - b.y;
    final cbx = c.x - b.x;
    final cby = c.y - b.y;

    final dot = abx * cbx + aby * cby;
    final magAb = math.sqrt(abx * abx + aby * aby);
    final magCb = math.sqrt(cbx * cbx + cby * cby);
    if (magAb == 0 || magCb == 0) return 0;

    final cosValue = (dot / (magAb * magCb)).clamp(-1.0, 1.0);
    return math.acos(cosValue) * 180 / math.pi;
  }

  double _dist(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }
}
