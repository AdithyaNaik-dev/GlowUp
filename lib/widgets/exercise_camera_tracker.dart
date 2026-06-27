import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/exercise.dart';
import '../services/exercise_rep_counter.dart';
import '../services/mediapipe_bridge_service.dart';

class ExerciseCameraTracker extends StatefulWidget {
  final Exercise exercise;
  final bool isPaused;
  final ValueChanged<TrackingSnapshot> onSnapshot;

  // Monotonic counter. Each increment from the parent loosens detection one
  // notch (stage-1 stuck rescue) via ExerciseRepCounter.boostSensitivity().
  final int sensitivityBoost;

  const ExerciseCameraTracker({
    super.key,
    required this.exercise,
    required this.isPaused,
    required this.onSnapshot,
    this.sensitivityBoost = 0,
  });

  @override
  State<ExerciseCameraTracker> createState() => _ExerciseCameraTrackerState();
}

class _ExerciseCameraTrackerState extends State<ExerciseCameraTracker> {
  final MediapipeBridgeService _mediapipeBridge = MediapipeBridgeService();
  final ExerciseRepCounter _repCounter = ExerciseRepCounter();

  CameraController? _controller;
  bool _isInitializing = true;
  bool _isCameraReady = false;
  bool _isProcessing = false;
  bool _isCameraOff = false;
  String _cameraMessage = 'Camera unavailable';
  int _frameCount = 0;
  late TrackingSnapshot _latestSnapshot;

  @override
  void initState() {
    super.initState();
    _repCounter.resetForExercise(widget.exercise.name, difficulty: widget.exercise.difficulty.toLowerCase());
    _latestSnapshot = TrackingSnapshot(
      currentExercise: widget.exercise.name,
      repCount: 0,
      isRepInProgress: false,
      previousState: 'idle',
      statusText: 'Get ready',
      isHoldExercise: _repCounter.isHoldExercise,
      holdSeconds: 0,
    );
    _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant ExerciseCameraTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.name != widget.exercise.name) {
      _repCounter.resetForExercise(widget.exercise.name, difficulty: widget.exercise.difficulty.toLowerCase());
      _latestSnapshot = TrackingSnapshot(
        currentExercise: widget.exercise.name,
        repCount: 0,
        isRepInProgress: false,
        previousState: 'idle',
        statusText: 'Get ready',
        isHoldExercise: _repCounter.isHoldExercise,
        holdSeconds: 0,
      );
    }
    // Parent asked to loosen detection (user appears stuck).
    if (widget.sensitivityBoost > oldWidget.sensitivityBoost) {
      _repCounter.boostSensitivity();
    }
  }

  @override
  void dispose() {
    final cameraController = _controller;
    _controller = null;
    cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    setState(() => _isInitializing = true);
    try {
      final cameras = await availableCameras();
      CameraDescription? front;
      for (final cam in cameras) {
        if (cam.lensDirection == CameraLensDirection.front) {
          front = cam;
          break;
        }
      }

      final selectedCamera = front ?? (cameras.isNotEmpty ? cameras.first : null);
      if (selectedCamera == null) {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _isCameraReady = false;
          });
        }
        return;
      }

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await controller.initialize();
      await controller.startImageStream(_onFrame);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitializing = false;
        _isCameraReady = true;
      });
    } catch (error) {
      if (error is CameraException) {
        final cameraError = error;
        if (cameraError.code == 'CameraAccessDenied') {
          _cameraMessage = 'Camera permission denied';
        } else if (cameraError.code == 'CameraAccessDeniedWithoutPrompt') {
          _cameraMessage = 'Enable camera permission in settings';
        }
      }
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _isCameraReady = false;
      });
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (!_isCameraReady || _isCameraOff || widget.isPaused || _isProcessing) {
      return;
    }

    final useFace = isFaceExercise(widget.exercise.name);

    // Process every frame for face (fast model), every 2nd for body
    _frameCount += 1;
    if (!useFace && _frameCount % 2 != 0) {
      return;
    }

    _isProcessing = true;
    try {
      final bytes = _joinPlanes(image.planes);
      final rotation = _controller?.description.sensorOrientation ?? 0;

      final result = await _mediapipeBridge.processFrame(
        bytes: bytes,
        width: image.width,
        height: image.height,
        rotation: rotation,
        exerciseName: widget.exercise.name,
        useFaceMesh: useFace,
        usePose: !useFace,
      );

      if (!mounted) return;

      final snapshot = _repCounter.update(
        exerciseName: widget.exercise.name,
        poseLandmarks: result.poseLandmarks,
        faceLandmarks: result.faceLandmarks,
        timestamp: DateTime.now(),
        difficulty: widget.exercise.difficulty.toLowerCase(),
      );

      if (snapshot.repJustCounted) {
        HapticFeedback.mediumImpact();
      }

      if (mounted) {
        setState(() {
          _latestSnapshot = snapshot;
        });
      }
      widget.onSnapshot(snapshot);
    } finally {
      _isProcessing = false;
    }
  }

  Uint8List _joinPlanes(List<Plane> planes) {
    final writeBuffer = WriteBuffer();
    for (final plane in planes) {
      writeBuffer.putUint8List(plane.bytes);
    }
    return writeBuffer.done().buffer.asUint8List();
  }

  Future<void> _toggleCameraPower() async {
    final controller = _controller;
    if (controller == null) return;

    if (_isCameraOff) {
      try {
        await controller.resumePreview();
      } catch (_) {}
      if (!controller.value.isStreamingImages) {
        await controller.startImageStream(_onFrame);
      }
      if (!mounted) return;
      setState(() => _isCameraOff = false);
      return;
    }

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    try {
      await controller.pausePreview();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _isCameraOff = true);
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _latestSnapshot;
    final hasGuidance = snapshot.guidanceHint != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: _isInitializing
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white24,
                        strokeWidth: 2,
                      ),
                    )
                  : _isCameraReady && _controller != null
                      ? (_isCameraOff
                          ? Center(
                              child: Icon(Icons.videocam_off_rounded,
                                  color: Colors.white.withAlpha(60), size: 40),
                            )
                          : _buildMirroredPreview(_controller!))
                      : Center(
                          child: Text(_cameraMessage,
                              style: TextStyle(
                                  color: Colors.white.withAlpha(120),
                                  fontSize: 13)),
                        ),
            ),
            // Subtle bottom gradient for text readability
            Positioned(
              bottom: 0, left: 0, right: 0,
              height: 80,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(180),
                    ],
                  ),
                ),
              ),
            ),
            // Camera toggle — minimal icon, top-right
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: _toggleCameraPower,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(90),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isCameraOff
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    color: Colors.white70,
                    size: 18,
                  ),
                ),
              ),
            ),
            // Status + guidance at bottom
            Positioned(
              bottom: 12,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status text — clean, no pill
                  Text(
                    snapshot.statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _getStatusColor(snapshot.statusText),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: 0.3,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                  // Guidance hint — smaller, below
                  if (hasGuidance) ...[
                    const SizedBox(height: 4),
                    Text(
                      snapshot.guidanceHint!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('Good') || status == 'Go!') {
      return const Color(0xFF4ADE80); // soft green
    }
    if (status.contains('not visible') || status.contains('Move') ||
        status.contains('Step') || status.contains('Position')) {
      return const Color(0xFFFBBF24); // soft amber
    }
    if (status.contains('Stay still')) {
      return const Color(0xFF60A5FA); // soft blue
    }
    return Colors.white;
  }

  Widget _buildMirroredPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    final width = previewSize?.height ?? 1280;
    final height = previewSize?.width ?? 720;

    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: width,
          height: height,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}
