import 'dart:math' as math;

import 'mediapipe_bridge_service.dart';

enum ExerciseMode { aiTracked, timerBased, manual }

// Three-phase flow that every exercise goes through:
//   waiting   → user hasn't been detected yet (placing phone, stepping back)
//   calibrating → user is detected, collecting their neutral baseline
//   tracking  → baseline locked, reps are counting
enum TrackingPhase { waiting, calibrating, tracking }

ExerciseMode getExerciseMode(String name) {
  final n = name.toLowerCase();
  if (n == 'plank' || n == 'wall sit' || n == 'dynamic plank' ||
      n.contains('mewing') || n.contains('tongue suction') ||
      n == 'neck extensions' || n == 'neck lift' || n == 'jaw clench hold' ||
      n == 'star crunch' || n == 'tuck crunches' || n == 'rear lunges' ||
      n == 'left wink' || n == 'right wink') {
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
  final double trackingConfidence;
  final bool repJustCounted;
  final int calibrationCountdown;
  final TrackingPhase phase;
  // true on the single frame where phase flips to `tracking` (voice says "Go!")
  final bool justStartedTracking;

  const TrackingSnapshot({
    required this.currentExercise,
    required this.repCount,
    required this.isRepInProgress,
    required this.previousState,
    required this.statusText,
    required this.isHoldExercise,
    required this.holdSeconds,
    this.guidanceHint,
    this.trackingConfidence = 1.0,
    this.repJustCounted = false,
    this.calibrationCountdown = 0,
    this.phase = TrackingPhase.waiting,
    this.justStartedTracking = false,
  });
}

class _SmoothedValue {
  double _value = 0;
  bool _initialized = false;

  double update(double raw, {double alpha = 0.45}) {
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

class _CalibrationCollector {
  final List<double> _samples = [];

  void add(double v) => _samples.add(v);

  double get median {
    if (_samples.isEmpty) return 0;
    final sorted = List<double>.from(_samples)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  bool get hasData => _samples.isNotEmpty;
  void clear() => _samples.clear();
}

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

  final Map<String, _SmoothedValue> _smoothed = {};
  final Map<String, _CalibrationCollector> _calSamples = {};

  final Map<String, double> _baseline = {};

  List<LandmarkPoint>? _lastValidFace;
  List<LandmarkPoint>? _lastValidPose;
  int _faceHoldFrames = 0;
  int _poseHoldFrames = 0;
  bool _usingBufferedFrame = false;

  int _debounceActive = 0;
  int _debounceReset = 0;
  static const int _requiredFrames = 2;

  double _trackingConfidence = 0;
  bool _repJustCounted = false;
  int _calibrationCountdown = 0;

  // 3-phase flow state
  TrackingPhase _trackingPhase = TrackingPhase.waiting;
  DateTime? _calibrationStartTime;
  bool _justStartedTracking = false;
  // How many consecutive frames the user has been detected during the waiting phase
  int _detectedFrames = 0;
  static const int _requiredDetectedFrames = 5; // ~0.3s of stable detection
  static const int _calibrationMs = 1500; // baseline collection duration

  // Continuously-learned movement range per signal (decaying running-max of
  // |signal - baseline|). A rep counts at ~25% of this, so a partial movement
  // is enough. Updated every frame, not just on the first rep.
  final Map<String, double> _peakDeviation = {};

  // Loosens every adaptive threshold at once. 1.0 = normal. Lowered by
  // boostSensitivity() when the user appears stuck (stage-1 rescue).
  double _sensitivityBoost = 1.0;

  bool get isRepInProgress => _phase == _RepPhase.active;

  double _getSmoothed(String key, double raw, {double alpha = 0.45}) {
    _smoothed.putIfAbsent(key, () => _SmoothedValue());
    return _smoothed[key]!.update(raw, alpha: alpha);
  }

  void _addCalSample(String key, double v) {
    _calSamples.putIfAbsent(key, () => _CalibrationCollector());
    _calSamples[key]!.add(v);
  }

  double _getCalMedian(String key, double fallback) {
    final col = _calSamples[key];
    if (col == null || !col.hasData) return fallback;
    return col.median;
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
    _smoothed.clear();
    _calSamples.clear();
    _baseline.clear();

    _lastValidFace = null;
    _lastValidPose = null;
    _faceHoldFrames = 0;
    _poseHoldFrames = 0;
    _usingBufferedFrame = false;
    _debounceActive = 0;
    _debounceReset = 0;
    _trackingConfidence = 0;
    _repJustCounted = false;
    _calibrationCountdown = 0;
    _peakDeviation.clear();
    _sensitivityBoost = 1.0;
    _trackingPhase = TrackingPhase.waiting;
    _calibrationStartTime = null;
    _justStartedTracking = false;
    _detectedFrames = 0;
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

    _repJustCounted = false;
    _justStartedTracking = false;

    final dt = _lastTimestamp == null
        ? Duration.zero
        : timestamp.difference(_lastTimestamp!);
    _lastTimestamp = timestamp;

    final normalized = exerciseName.toLowerCase();
    final isFace = isFaceExercise(normalized);

    // ── Frame buffering (hold last valid landmarks for a few frames) ──
    _usingBufferedFrame = false;
    if (faceLandmarks.isNotEmpty) {
      _lastValidFace = faceLandmarks;
      _faceHoldFrames = 0;
    } else if (_lastValidFace != null && _faceHoldFrames < 8) {
      faceLandmarks = _lastValidFace!;
      _faceHoldFrames++;
      _usingBufferedFrame = true;
    }

    if (poseLandmarks.isNotEmpty) {
      _lastValidPose = poseLandmarks;
      _poseHoldFrames = 0;
    } else if (_lastValidPose != null && _poseHoldFrames < 8) {
      poseLandmarks = _lastValidPose!;
      _poseHoldFrames++;
      _usingBufferedFrame = true;
    }

    // ── Detect whether the user is visible this frame ──
    final bool userVisible;
    if (isFace) {
      userVisible = faceLandmarks.isNotEmpty;
    } else {
      final visible = poseLandmarks.where((l) => l.visibility >= 0.3);
      userVisible = poseLandmarks.isNotEmpty &&
          visible.length / poseLandmarks.length >= 0.3;
    }

    // ══════════════════════════════════════════════════════════════════
    //  PHASE 1: WAITING — user not in position yet
    // ══════════════════════════════════════════════════════════════════
    if (_trackingPhase == TrackingPhase.waiting) {
      if (userVisible) {
        _detectedFrames++;
      } else {
        _detectedFrames = 0;
      }

      if (_detectedFrames >= _requiredDetectedFrames) {
        // User is stable in frame → move to calibration
        _trackingPhase = TrackingPhase.calibrating;
        _calibrationStartTime = DateTime.now();

        statusText = 'Stay still...';
      } else {
        // Still waiting for user
        if (isFace) {
          statusText = 'Position your face';
          guidanceHint = 'Look at the camera';
        } else {
          statusText = 'Get into position';
          guidanceHint = 'Step back so your full body is visible';
        }
      }

      return _buildSnapshot();
    }

    // ══════════════════════════════════════════════════════════════════
    //  PHASE 2: CALIBRATING — user detected, collecting baseline
    // ══════════════════════════════════════════════════════════════════
    if (_trackingPhase == TrackingPhase.calibrating) {
      final calElapsed = _calibrationStartTime != null
          ? DateTime.now().difference(_calibrationStartTime!).inMilliseconds
          : 0;

      if (!userVisible) {
        // User left frame during calibration → back to waiting
        _trackingPhase = TrackingPhase.waiting;
        _detectedFrames = 0;
        _calSamples.clear();
        _smoothed.clear();
        statusText = isFace ? 'Position your face' : 'Get into position';
        return _buildSnapshot();
      }

      statusText = 'Stay still...';
      guidanceHint = null;

      // Feed landmark data into the calibration collectors. The face/body
      // update methods check _trackingPhase == calibrating and call
      // _addCalSample to collect the user's neutral baseline.
      if (isFace) {
        _updateFaceExercise(normalized, faceLandmarks, dt);
      } else {
        _updateBodyExercise(normalized, poseLandmarks, dt);
      }

      if (calElapsed >= _calibrationMs) {
        // Baseline collected → start tracking!
        _trackingPhase = TrackingPhase.tracking;
        _justStartedTracking = true;
        statusText = 'Go!';
        guidanceHint = null;
      }

      return _buildSnapshot();
    }

    // ══════════════════════════════════════════════════════════════════
    //  PHASE 3: TRACKING — active rep counting
    // ══════════════════════════════════════════════════════════════════
    _calibrationCountdown = 0;

    if (isFace) {
      _updateFaceExercise(normalized, faceLandmarks, dt);
    } else {
      _updateBodyExercise(normalized, poseLandmarks, dt);
    }

    return _buildSnapshot();
  }

  TrackingSnapshot _buildSnapshot() {
    return TrackingSnapshot(
      currentExercise: currentExercise,
      repCount: repCount,
      isRepInProgress: isRepInProgress,
      previousState: previousState,
      statusText: statusText,
      isHoldExercise: isHoldExercise,
      holdSeconds: _holdDuration.inSeconds,
      guidanceHint: guidanceHint,
      trackingConfidence: _trackingConfidence,
      repJustCounted: _repJustCounted,
      calibrationCountdown: _calibrationCountdown,
      phase: _trackingPhase,
      justStartedTracking: _justStartedTracking,
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
      _trackingConfidence = 0;
      if (_isHold(exercise)) {
        statusText = 'Hold position';
        _updateHoldTracking(exercise, dt, true);
        return;
      }
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

    const faceKeyIds = [1, 13, 14, 33, 61, 145, 159, 263, 291, 374, 386];
    int found = 0;
    for (final id in faceKeyIds) {
      if (byId.containsKey(id)) found++;
    }
    _trackingConfidence = found / faceKeyIds.length;

    final eyeL = byId[33];
    final eyeR = byId[263];
    double refDist = 0.18;
    if (eyeL != null && eyeR != null) {
      final measured = _dist(eyeL.x, eyeL.y, eyeR.x, eyeR.y);
      if (measured > 0.02) refDist = measured;
    }

    double? ndist(int a, int b) {
      final p1 = byId[a];
      final p2 = byId[b];
      if (p1 == null || p2 == null) return null;
      return _dist(p1.x, p1.y, p2.x, p2.y) / refDist;
    }

    final inCalibration = _trackingPhase == TrackingPhase.calibrating;

    switch (exercise) {
      case 'jaw open-close':
      case 'jaw open close':
      case 'mouth open':
        final raw = ndist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('mouth_v', raw, alpha: 0.5);
        if (inCalibration) { _addCalSample('mouth', v); return; }
        _baseline.putIfAbsent('mouth', () => _getCalMedian('mouth', 0.08));
        final base = _baseline['mouth']!;
        final off = _adaptiveOffset('mouth', 0.04);
        _countWithStateMachine(
          active: v > base + off, reset: v < base + off * 0.4,
          signal: v, adaptiveKey: 'mouth', baseline: base,
        );
        break;

      case 'smile':
        final raw = ndist(61, 291);
        if (raw == null) return;
        final v = _getSmoothed('smile_w', raw, alpha: 0.5);
        if (inCalibration) { _addCalSample('smile', v); return; }
        _baseline.putIfAbsent('smile', () => _getCalMedian('smile', 1.4));
        final base = _baseline['smile']!;
        final off = _adaptiveOffset('smile', 0.08);
        _countWithStateMachine(
          active: v > base + off, reset: v < base + off * 0.35,
          signal: v, adaptiveKey: 'smile', baseline: base,
        );
        break;

      case 'blink':
        final leftH = ndist(159, 145);
        final rightH = ndist(386, 374);
        if (leftH == null || rightH == null) return;
        final v = _getSmoothed('blink', (leftH + rightH) / 2, alpha: 0.65);
        if (inCalibration) { _addCalSample('blink', v); return; }
        _baseline.putIfAbsent('blink', () => _getCalMedian('blink', 0.14));
        final base = _baseline['blink']!;
        _countWithStateMachine(active: v < base * 0.60, reset: v > base * 0.72);
        break;

      case 'eyebrow raise':
        // Outer brow landmarks have more range; anchored to nose (doesn't move with brows)
        final lb = byId[105]; final rb = byId[334];
        final noseAnchor = byId[1];
        if (lb == null || rb == null || noseAnchor == null) return;
        final raw = ((noseAnchor.y - lb.y).abs() + (noseAnchor.y - rb.y).abs()) / 2 / refDist;
        final v = _getSmoothed('eyebrow', raw, alpha: 0.5);
        if (inCalibration) { _addCalSample('eyebrow', v); return; }
        _baseline.putIfAbsent('eyebrow', () => _getCalMedian('eyebrow', 0.50));
        final base = _baseline['eyebrow']!;
        final off = _adaptiveOffset('eyebrow', 0.008);
        _countWithStateMachine(
          active: v > base + off, reset: v < base + off * 0.4,
          signal: v, adaptiveKey: 'eyebrow', baseline: base,
        );
        break;

      case 'lip pucker':
        final raw = ndist(61, 291);
        if (raw == null) return;
        final v = _getSmoothed('pucker', raw, alpha: 0.5);
        if (inCalibration) { _addCalSample('pucker', v); return; }
        _baseline.putIfAbsent('pucker', () => _getCalMedian('pucker', 1.4));
        final base = _baseline['pucker']!;
        final off = _adaptiveOffset('pucker', 0.07);
        _countWithStateMachine(
          active: v < base - off, reset: v > base - off * 0.4,
          signal: v, adaptiveKey: 'pucker', baseline: base,
        );
        break;

      case 'jaw shift':
        final chin = byId[152]; final nose = byId[1];
        if (chin == null || nose == null) return;
        final v = _getSmoothed('jawshift', (chin.x - nose.x) / refDist, alpha: 0.45);
        if (inCalibration) { _addCalSample('jawshift', v); return; }
        _baseline.putIfAbsent('jawshift', () => _getCalMedian('jawshift', 0));
        final base = _baseline['jawshift']!;
        final off = _adaptiveOffset('jawshift', 0.05);
        final deviation = (v - base).abs();
        _countWithStateMachine(
          active: deviation > off, reset: deviation < off * 0.45,
          signal: deviation, adaptiveKey: 'jawshift', baseline: 0,
        );
        break;

      case 'chin lift':
      case 'neck raise':
        final raw = ndist(152, 1);
        if (raw == null) return;
        final v = _getSmoothed('chinlift', raw, alpha: 0.4);
        if (inCalibration) { _addCalSample('chinlift', v); return; }
        _baseline.putIfAbsent('chinlift', () => _getCalMedian('chinlift', 0.83));
        final base = _baseline['chinlift']!;
        final off = _adaptiveOffset('chinlift', 0.045);
        _countWithStateMachine(
          active: v > base + off, reset: v < base + off * 0.35,
          signal: v, adaptiveKey: 'chinlift', baseline: base,
        );
        break;

      case 'fish face':
        final mouthW = ndist(61, 291);
        final mouthH = ndist(13, 14);
        if (mouthW == null || mouthH == null) return;
        final vW = _getSmoothed('fishface_w', mouthW, alpha: 0.45);
        final vH = _getSmoothed('fishface_h', mouthH, alpha: 0.45);
        if (inCalibration) { _addCalSample('fishface_w', vW); _addCalSample('fishface_h', vH); return; }
        _baseline.putIfAbsent('fishface_w', () => _getCalMedian('fishface_w', 1.4));
        _baseline.putIfAbsent('fishface_h', () => _getCalMedian('fishface_h', 0.08));
        final baseW = _baseline['fishface_w']!;
        final baseH = _baseline['fishface_h']!;
        final off = _adaptiveOffset('fishface_w', 0.06);
        _countWithStateMachine(
          active: vW < baseW - off && vH < baseH + 0.03,
          reset: vW > baseW - off * 0.35,
          signal: vW, adaptiveKey: 'fishface_w', baseline: baseW,
        );
        break;

      case 'jaw resistance':
        final raw = ndist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('jawres', raw, alpha: 0.5);
        if (inCalibration) { _addCalSample('jawres', v); return; }
        _baseline.putIfAbsent('jawres', () => _getCalMedian('jawres', 0.08));
        final base = _baseline['jawres']!;
        final off = _adaptiveOffset('jawres', 0.04);
        _countWithStateMachine(
          active: v > base + off, reset: v < base + off * 0.4,
          signal: v, adaptiveKey: 'jawres', baseline: base,
        );
        break;

      case 'cheek lift':
        final raw = ndist(61, 291);
        if (raw == null) return;
        final v = _getSmoothed('cheeklift', raw, alpha: 0.45);
        if (inCalibration) { _addCalSample('cheeklift', v); return; }
        _baseline.putIfAbsent('cheeklift', () => _getCalMedian('cheeklift', 1.4));
        final base = _baseline['cheeklift']!;
        final off = _adaptiveOffset('cheeklift', 0.06);
        _countWithStateMachine(
          active: v > base + off, reset: v < base + off * 0.35,
          signal: v, adaptiveKey: 'cheeklift', baseline: base,
        );
        break;

      case 'eye widening':
        final lo = ndist(159, 145);
        final ro = ndist(386, 374);
        if (lo == null || ro == null) return;
        final v = _getSmoothed('eyewiden', (lo + ro) / 2, alpha: 0.5);
        if (inCalibration) { _addCalSample('eyewiden', v); return; }
        _baseline.putIfAbsent('eyewiden', () => _getCalMedian('eyewiden', 0.12));
        final base = _baseline['eyewiden']!;
        final off = _adaptiveOffset('eyewiden', 0.025);
        _countWithStateMachine(
          active: v > base + off, reset: v < base + off * 0.4,
          signal: v, adaptiveKey: 'eyewiden', baseline: base,
        );
        break;

      case 'mewing':
      case 'tongue suction (mewing)':
      case 'tongue suction':
        final raw = ndist(13, 14);
        if (raw == null) return;
        final v = _getSmoothed('mewing', raw, alpha: 0.4);
        if (inCalibration) { _addCalSample('mewing', v); return; }
        _baseline.putIfAbsent('mewing', () => _getCalMedian('mewing', 0.08));
        final base = _baseline['mewing']!;
        final good = v < base + 0.02;
        statusText = good ? 'Good form' : 'Close your mouth';
        _updateHoldTracking(exercise, dt, good);
        break;

      case 'left wink':
      case 'right wink':
      case 'neck extensions':
      case 'neck lift':
      case 'jaw clench hold':
        statusText = 'Hold position';
        _updateHoldTracking(exercise, dt, true);
        break;

      case 'surprised face':
        // Count when mouth opens wide (most reliable signal for surprised expression)
        final rawM = ndist(13, 14);
        if (rawM == null) return;
        final vM = _getSmoothed('surprised_mouth', rawM, alpha: 0.5);
        if (inCalibration) { _addCalSample('surprised_mouth', vM); return; }
        _baseline.putIfAbsent('surprised_mouth', () => _getCalMedian('surprised_mouth', 0.08));
        final baseMouth = _baseline['surprised_mouth']!;
        final mOff = _adaptiveOffset('surprised_mouth', 0.03);
        _countWithStateMachine(
          active: vM > baseMouth + mOff,
          reset: vM < baseMouth + mOff * 0.4,
          signal: vM, adaptiveKey: 'surprised_mouth', baseline: baseMouth,
        );
        break;

      case 'cheek puff':
        _trackCheekPuff(byId, refDist, inCalibration);
        break;

      case 'o face':
        final rawW = ndist(61, 291);
        final rawH = ndist(13, 14);
        if (rawW == null || rawH == null) return;
        final vW = _getSmoothed('oface_width', rawW, alpha: 0.5);
        final vH = _getSmoothed('oface_height', rawH, alpha: 0.5);
        if (inCalibration) {
          _addCalSample('oface_width', vW);
          _addCalSample('oface_height', vH);
          return;
        }
        _baseline.putIfAbsent('oface_width', () => _getCalMedian('oface_width', 1.4));
        _baseline.putIfAbsent('oface_height', () => _getCalMedian('oface_height', 0.08));
        final baseW = _baseline['oface_width']!;
        final baseH = _baseline['oface_height']!;
        final wOff = _adaptiveOffset('oface_width', 0.03);
        final hOff = _adaptiveOffset('oface_height', 0.025);
        _countWithStateMachine(
          active: vW < baseW - wOff && vH > baseH + hOff,
          reset: vW > baseW - wOff * 0.4,
        );
        break;

      case 'nose scrunch':
        final upperLip = byId[0];
        final noseTip = byId[1];
        final innerEyeL = byId[133]; final innerEyeR = byId[362];
        if (upperLip == null || noseTip == null) return;
        final lipToNose = _dist(upperLip.x, upperLip.y, noseTip.x, noseTip.y) / refDist;
        final vLip = _getSmoothed('nscrunch_lip', lipToNose, alpha: 0.5);
        double vEyeNose = 0;
        if (innerEyeL != null && innerEyeR != null) {
          final eyeToNose = (_dist(innerEyeL.x, innerEyeL.y, noseTip.x, noseTip.y) +
                            _dist(innerEyeR.x, innerEyeR.y, noseTip.x, noseTip.y)) / 2 / refDist;
          vEyeNose = _getSmoothed('nscrunch_eye', eyeToNose, alpha: 0.5);
        }
        if (inCalibration) {
          _addCalSample('nscrunch_lip', vLip);
          if (vEyeNose > 0) _addCalSample('nscrunch_eye', vEyeNose);
          return;
        }
        _baseline.putIfAbsent('nscrunch_lip', () => _getCalMedian('nscrunch_lip', 0.25));
        _baseline.putIfAbsent('nscrunch_eye', () => _getCalMedian('nscrunch_eye', 0.70));
        final baseLip = _baseline['nscrunch_lip']!;
        final baseEye = _baseline['nscrunch_eye']!;
        final lipOff = _adaptiveOffset('nscrunch_lip', 0.02);
        final lipActive = vLip < baseLip - lipOff;
        final eyeActive = vEyeNose > 0 && vEyeNose < baseEye - 0.02;
        _countWithStateMachine(
          active: lipActive || eyeActive,
          reset: vLip > baseLip - lipOff * 0.35,
          signal: vLip, adaptiveKey: 'nscrunch_lip', baseline: baseLip,
        );
        break;

      default:
        statusText = 'Tracking';
    }
  }

  void _trackCheekPuff(Map<int, LandmarkPoint> byId, double refDist, bool inCalibration) {
    final cheekL = byId[50]; final cheekR = byId[280];
    final faceL = byId[234]; final faceR = byId[454];
    final jawL = byId[172]; final jawR = byId[397];
    final upperLip = byId[13]; final lowerLip = byId[14];
    final noseSideL = byId[102]; final noseSideR = byId[331];
    final cheekMidL = byId[205]; final cheekMidR = byId[425];

    if (cheekL == null || cheekR == null || upperLip == null || lowerLip == null) return;

    final vCheek = _getSmoothed('cpuff_cheek',
        _dist(cheekL.x, cheekL.y, cheekR.x, cheekR.y) / refDist, alpha: 0.5);

    double vContour = 0;
    if (faceL != null && faceR != null) {
      vContour = _getSmoothed('cpuff_contour',
          _dist(faceL.x, faceL.y, faceR.x, faceR.y) / refDist, alpha: 0.5);
    }

    double vJaw = 0;
    if (jawL != null && jawR != null) {
      vJaw = _getSmoothed('cpuff_jaw',
          _dist(jawL.x, jawL.y, jawR.x, jawR.y) / refDist, alpha: 0.5);
    }

    final vMouth = _getSmoothed('cpuff_mouth',
        _dist(upperLip.x, upperLip.y, lowerLip.x, lowerLip.y) / refDist, alpha: 0.5);

    double vNasolabial = 0;
    if (noseSideL != null && cheekMidL != null && noseSideR != null && cheekMidR != null) {
      vNasolabial = _getSmoothed('cpuff_nasolabial',
          (_dist(noseSideL.x, noseSideL.y, cheekMidL.x, cheekMidL.y) +
           _dist(noseSideR.x, noseSideR.y, cheekMidR.x, cheekMidR.y)) / 2 / refDist,
          alpha: 0.5);
    }

    if (inCalibration) {
      _addCalSample('cpuff_cheek', vCheek);
      if (vContour > 0) _addCalSample('cpuff_contour', vContour);
      if (vJaw > 0) _addCalSample('cpuff_jaw', vJaw);
      _addCalSample('cpuff_mouth', vMouth);
      if (vNasolabial > 0) _addCalSample('cpuff_nasolabial', vNasolabial);
      statusText = 'Get ready...';
      return;
    }

    _baseline.putIfAbsent('cpuff_cheek', () => _getCalMedian('cpuff_cheek', 1.95));
    _baseline.putIfAbsent('cpuff_contour', () => _getCalMedian('cpuff_contour', 2.5));
    _baseline.putIfAbsent('cpuff_jaw', () => _getCalMedian('cpuff_jaw', 1.6));
    _baseline.putIfAbsent('cpuff_mouth', () => _getCalMedian('cpuff_mouth', 0.08));
    _baseline.putIfAbsent('cpuff_nasolabial', () => _getCalMedian('cpuff_nasolabial', 0.3));

    int puffScore = 0;
    int releaseScore = 0;
    int totalSignals = 0;

    totalSignals++;
    if (vCheek > _baseline['cpuff_cheek']! + 0.008) puffScore++;
    if (vCheek < _baseline['cpuff_cheek']! + 0.003) releaseScore++;

    if (vContour > 0) {
      totalSignals++;
      if (vContour > _baseline['cpuff_contour']! + 0.006) puffScore++;
      if (vContour < _baseline['cpuff_contour']! + 0.002) releaseScore++;
    }

    if (vJaw > 0) {
      totalSignals++;
      if (vJaw > _baseline['cpuff_jaw']! + 0.006) puffScore++;
      if (vJaw < _baseline['cpuff_jaw']! + 0.002) releaseScore++;
    }

    if (vNasolabial > 0) {
      totalSignals++;
      if (vNasolabial > _baseline['cpuff_nasolabial']! + 0.005) puffScore++;
      if (vNasolabial < _baseline['cpuff_nasolabial']! + 0.002) releaseScore++;
    }

    final mouthClosed = vMouth < _baseline['cpuff_mouth']! + 0.08;
    final puffed = puffScore >= 1 && mouthClosed;
    final released = releaseScore >= math.max(1, totalSignals - 1);

    _countWithStateMachine(active: puffed, reset: released);
  }

  // ════════════════════════════════════════════
  //  BODY EXERCISES
  // ════════════════════════════════════════════
  void _updateBodyExercise(
    String exercise,
    List<LandmarkPoint> landmarks,
    Duration dt,
  ) {
    guidanceHint = null;

    if (landmarks.isEmpty) {
      _missingFrames++;
      _trackingConfidence = 0;
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
    _trackingConfidence = visibleRatio;

    if (visibleRatio < 0.3) {
      _missingFrames++;
      statusText = 'Move into frame';
      guidanceHint = 'Step back — full body not visible';
      return;
    }
    _missingFrames = 0;

    final byId = {for (final point in visible) point.id: point};

    final leftSh = byId[11];
    final rightSh = byId[12];
    double bodyScale = 1.0;
    if (leftSh != null && rightSh != null) {
      final sw = _dist(leftSh.x, leftSh.y, rightSh.x, rightSh.y);
      if (sw > 0.02) bodyScale = sw / 0.25;
    }

    final hasUpperBody = byId.containsKey(11) && byId.containsKey(12);
    final hasLowerBody = byId.containsKey(27) || byId.containsKey(28);

    if (!hasUpperBody) {
      guidanceHint = 'Move back — shoulders not visible';
    } else if (!hasLowerBody && !exercise.contains('push')) {
      guidanceHint = 'Step back — legs not visible';
    }

    switch (exercise) {
      case 'jumping jacks':
        final lw = byId[15]; final rw = byId[16];
        final ls = byId[11]; final rs = byId[12];
        if (lw == null || rw == null || ls == null || rs == null) {
          statusText = 'Show full arms';
          return;
        }
        final jjAllow = _boostAllow(bodyScale);
        _countWithStateMachine(
          active: lw.y < ls.y + 0.06 * bodyScale + jjAllow ||
              rw.y < rs.y + 0.06 * bodyScale + jjAllow,
          reset: lw.y > ls.y + 0.05 * bodyScale && rw.y > rs.y + 0.05 * bodyScale,
        );
        break;

      case 'squats':
        final leftKnee = _safeAngle(byId, 23, 25, 27);
        final rightKnee = _safeAngle(byId, 24, 26, 28);
        if (leftKnee != null || rightKnee != null) {
          final knee = _getSmoothed('squat_knee',
              leftKnee != null && rightKnee != null
                  ? (leftKnee + rightKnee) / 2
                  : (leftKnee ?? rightKnee!), alpha: 0.4);
          // Higher angle = straighter leg, so a shallower squat counts.
          final activeAngle = 160 + (1.0 - _sensitivityBoost) * 12;
          _countWithStateMachine(
            active: knee < activeAngle, reset: knee > activeAngle + 6,
            peakHint: 'Go lower',
          );
        } else {
          final hip = byId[23] ?? byId[24];
          if (hip != null) {
            final v = _getSmoothed('squat_hip', hip.y, alpha: 0.4);
            _baseline.putIfAbsent('squat_hip', () => v);
            final base = _baseline['squat_hip']!;
            _countWithStateMachine(
              active: v > base + 0.018 * bodyScale * _sensitivityBoost,
              reset: v < base + 0.009 * bodyScale,
              peakHint: 'Go lower',
            );
          }
        }
        break;

      case 'high knees':
        final lk = byId[25]; final rk = byId[26];
        final lh = byId[23]; final rh = byId[24];
        final hkAllow = _boostAllow(bodyScale);
        if (lk != null && lh != null) {
          final leftUp = lk.y < lh.y + 0.10 * bodyScale + hkAllow;
          if (leftUp && !_leftSideTriggered) {
            if (_canCountRep()) {
              repCount++; _repJustCounted = true;
              _lastRepTime = DateTime.now(); _leftSideTriggered = true;
              statusText = 'Good!';
            }
          }
          if (!leftUp) _leftSideTriggered = false;
        }
        if (rk != null && rh != null) {
          final rightUp = rk.y < rh.y + 0.10 * bodyScale + hkAllow;
          if (rightUp && !_rightSideTriggered) {
            if (_canCountRep()) {
              repCount++; _repJustCounted = true;
              _lastRepTime = DateTime.now(); _rightSideTriggered = true;
              statusText = 'Good!';
            }
          }
          if (!rightUp) _rightSideTriggered = false;
        }
        if (!_leftSideTriggered && !_rightSideTriggered) statusText = 'Lift knees higher';
        break;

      case 'arm raises':
      case 'front raise':
        final lw = byId[15]; final rw = byId[16];
        final ls = byId[11]; final rs = byId[12];
        if (lw == null || rw == null || ls == null || rs == null) return;
        final arAllow = _boostAllow(bodyScale);
        _countWithStateMachine(
          active: lw.y < ls.y + 0.06 * bodyScale + arAllow &&
              rw.y < rs.y + 0.06 * bodyScale + arAllow,
          reset: lw.y > ls.y + 0.05 * bodyScale && rw.y > rs.y + 0.05 * bodyScale,
          peakHint: 'Raise higher',
        );
        break;

      case 'pushups':
      case 'push-ups':
        final nose = byId[0];
        final shoulder = byId[11] ?? byId[12];
        final trackPoint = nose ?? shoulder;
        if (trackPoint != null) {
          final v = _getSmoothed('pushup_y', trackPoint.y, alpha: 0.4);
          _baseline.putIfAbsent('pushup_y', () => v);
          final base = _baseline['pushup_y']!;
          _countWithStateMachine(
            active: v > base + 0.014 * bodyScale * _sensitivityBoost,
            reset: v < base + 0.006 * bodyScale,
            peakHint: 'Go lower',
          );
        }
        break;

      case 'standing knee raises':
        // Each knee raise = 1 rep (same pattern as high knees)
        final skLk = byId[25]; final skRk = byId[26];
        final skLh = byId[23]; final skRh = byId[24];
        final skAllow = _boostAllow(bodyScale);
        if (skLk != null && skLh != null) {
          final leftUp = skLk.y < skLh.y + 0.10 * bodyScale + skAllow;
          if (leftUp && !_leftSideTriggered) {
            if (_canCountRep()) {
              repCount++; _repJustCounted = true;
              _lastRepTime = DateTime.now(); _leftSideTriggered = true;
              statusText = 'Good!';
            }
          }
          if (!leftUp) _leftSideTriggered = false;
        }
        if (skRk != null && skRh != null) {
          final rightUp = skRk.y < skRh.y + 0.10 * bodyScale + skAllow;
          if (rightUp && !_rightSideTriggered) {
            if (_canCountRep()) {
              repCount++; _repJustCounted = true;
              _lastRepTime = DateTime.now(); _rightSideTriggered = true;
              statusText = 'Good!';
            }
          }
          if (!rightUp) _rightSideTriggered = false;
        }
        if (!_leftSideTriggered && !_rightSideTriggered) statusText = 'Raise knees higher';
        break;

      case 'mountain climbers':
        // Alternating: both knees must go up to count 1 rep
        final mcLk = byId[25]; final mcRk = byId[26];
        final mcLh = byId[23]; final mcRh = byId[24];
        final mcAllow = _boostAllow(bodyScale);
        if (mcLk != null && mcLh != null) {
          final leftUp = mcLk.y < mcLh.y + 0.08 * bodyScale + mcAllow;
          if (leftUp && !_leftSideTriggered) _leftSideTriggered = true;
          if (!leftUp) _leftSideTriggered = false;
        }
        if (mcRk != null && mcRh != null) {
          final rightUp = mcRk.y < mcRh.y + 0.08 * bodyScale + mcAllow;
          if (rightUp && !_rightSideTriggered) _rightSideTriggered = true;
          if (!rightUp) _rightSideTriggered = false;
        }
        if (_leftSideTriggered && _rightSideTriggered) {
          if (_canCountRep()) {
            repCount++; _repJustCounted = true;
            _lastRepTime = DateTime.now(); statusText = 'Good!';
          }
          _leftSideTriggered = false; _rightSideTriggered = false;
        } else {
          statusText = 'Drive knees up';
        }
        break;

      case 'side steps':
        final la = byId[27]; final ra = byId[28];
        final lh = byId[23]; final rh = byId[24];
        if (la == null || ra == null || lh == null || rh == null) return;
        final legSpread = _getSmoothed('sidestep', _dist(la.x, la.y, ra.x, ra.y), alpha: 0.45);
        final hipW = _dist(lh.x, lh.y, rh.x, rh.y);
        final ssActive = 1.35 - (1.0 - _sensitivityBoost) * 0.2;
        _countWithStateMachine(
            active: legSpread > hipW * ssActive, reset: legSpread < hipW * 1.15);
        break;

      case 'burpees':
        final shoulder = byId[11] ?? byId[12];
        if (shoulder != null) {
          final v = _getSmoothed('burpee_y', shoulder.y, alpha: 0.4);
          _baseline.putIfAbsent('burpee_y', () => v);
          final base = _baseline['burpee_y']!;
          _countWithStateMachine(
            active: v > base + 0.03 * bodyScale * _sensitivityBoost,
            reset: v < base + 0.012 * bodyScale,
          );
        }
        break;

      case 'plank':
      case 'wall sit':
        final shoulder = byId[11];
        final hip = byId[23];
        if (shoulder != null && hip != null) {
          final good = exercise == 'plank' ? _isPlankOk(byId) : _isWallSitOk(byId);
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

  // ─── State machine ───
  void _countWithStateMachine({
    required bool active,
    required bool reset,
    double? signal,
    String? adaptiveKey,
    double? baseline,
    String peakHint = 'Keep going',
    String resetHint = 'Good rep!',
  }) {
    if (_usingBufferedFrame) return;

    // Continuously learn the user's movement range (decaying running-max), so
    // _adaptiveOffset can trigger at ~25% of it — even before the first rep.
    if (signal != null && baseline != null && adaptiveKey != null) {
      final dev = (signal - baseline).abs();
      final prev = _peakDeviation[adaptiveKey] ?? 0;
      _peakDeviation[adaptiveKey] = math.max(dev, prev * 0.97);
    }

    if (active && _phase == _RepPhase.idle) {
      _debounceActive++;
      _debounceReset = 0;
      if (_debounceActive >= _requiredFrames) {
        _phase = _RepPhase.active;
        previousState = 'active';
        statusText = peakHint;
        _debounceActive = 0;
      }
      return;
    }

    if (!active && _phase == _RepPhase.idle) {
      _debounceActive = 0;
    }

    if (reset && _phase == _RepPhase.active) {
      _debounceReset++;
      if (_debounceReset >= _requiredFrames) {
        if (_canCountRep()) {
          repCount++;
          _repJustCounted = true;
          _lastRepTime = DateTime.now();
          statusText = resetHint;
        }
        _phase = _RepPhase.idle;
        previousState = 'idle';
        _debounceReset = 0;
      }
      return;
    }

    if (!reset && _phase == _RepPhase.active) {
      _debounceReset = 0;
      statusText = peakHint;
    }

    if (_phase == _RepPhase.idle && _debounceActive == 0) {
      statusText = 'Keep going';
    }
  }

  // How far from baseline the signal must move to count a rep. Very generous:
  // ~25% of the user's own learned range, capped so it is never harder than the
  // default and never below a small noise floor. _sensitivityBoost loosens it
  // further when the user looks stuck.
  double _adaptiveOffset(String key, double defaultOffset) {
    final peak = _peakDeviation[key] ?? 0;
    double offset;
    if (peak > 0) {
      offset = peak * 0.25; // 25% of the full movement triggers a rep
    } else {
      offset = defaultOffset * 0.6; // before any range is learned: already easy
    }
    offset = offset.clamp(defaultOffset * 0.3, defaultOffset);
    return offset * _sensitivityBoost;
  }

  /// Loosen every adaptive threshold at once. Called when the user appears
  /// stuck (no reps for a while). Each call relaxes detection further, down to
  /// a floor, so a struggling user starts getting counted.
  void boostSensitivity() {
    _sensitivityBoost = (_sensitivityBoost * 0.65).clamp(0.4, 1.0);
  }

  // Extra positional allowance for body exercises that compare a joint against
  // a reference (e.g. knee-above-hip). Grows as sensitivity is boosted so a
  // stuck user's smaller movements still register.
  double _boostAllow(double bodyScale) =>
      (1.0 - _sensitivityBoost) * 0.08 * bodyScale;

  bool _canCountRep() {
    if (_lastRepTime == null) return true;
    return DateTime.now().difference(_lastRepTime!).inMilliseconds > 250;
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
    return _angleFromPoints(shoulder, hip, ankle) > 120;
  }

  bool _isWallSitOk(Map<int, LandmarkPoint> byId) {
    final knee = _safeAngle(byId, 23, 25, 27);
    if (knee == null) return true;
    return knee > 50 && knee < 140;
  }

  double? _safeAngle(Map<int, LandmarkPoint> byId, int a, int b, int c) {
    final p1 = byId[a]; final p2 = byId[b]; final p3 = byId[c];
    if (p1 == null || p2 == null || p3 == null) return null;
    return _angleFromPoints(p1, p2, p3);
  }

  double _angleFromPoints(LandmarkPoint a, LandmarkPoint b, LandmarkPoint c) {
    final abx = a.x - b.x; final aby = a.y - b.y;
    final cbx = c.x - b.x; final cby = c.y - b.y;
    final dot = abx * cbx + aby * cby;
    final magAb = math.sqrt(abx * abx + aby * aby);
    final magCb = math.sqrt(cbx * cbx + cby * cby);
    if (magAb == 0 || magCb == 0) return 0;
    return math.acos((dot / (magAb * magCb)).clamp(-1.0, 1.0)) * 180 / math.pi;
  }

  double _dist(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2; final dy = y1 - y2;
    return math.sqrt(dx * dx + dy * dy);
  }
}
