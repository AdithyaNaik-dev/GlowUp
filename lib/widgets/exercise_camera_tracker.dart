import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/exercise.dart';
import '../services/exercise_rep_counter.dart';
import '../services/mediapipe_bridge_service.dart';

class ExerciseCameraTracker extends StatefulWidget {
  final Exercise exercise;
  final bool isPaused;
  final ValueChanged<TrackingSnapshot> onSnapshot;

  const ExerciseCameraTracker({
    super.key,
    required this.exercise,
    required this.isPaused,
    required this.onSnapshot,
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

    // Process every 2nd frame for performance
    _frameCount += 1;
    if (_frameCount % 2 != 0) {
      return;
    }

    _isProcessing = true;
    try {
      final bytes = _joinPlanes(image.planes);
      final rotation = _controller?.description.sensorOrientation ?? 0;

      final useFace = isFaceExercise(widget.exercise.name);

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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.secondary.withAlpha(80),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: _isInitializing
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.secondary,
                          strokeWidth: 2.5,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Starting camera...',
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : _isCameraReady && _controller != null
                ? (_isCameraOff
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_off_rounded,
                                  color: Colors.white.withAlpha(100), size: 48),
                              const SizedBox(height: 8),
                              Text('Camera paused',
                                  style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13)),
                            ],
                          ),
                        )
                      : _buildMirroredPreview(_controller!))
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt_rounded,
                            color: Colors.white.withAlpha(100), size: 48),
                        const SizedBox(height: 8),
                        Text(_cameraMessage,
                            style: TextStyle(color: Colors.white.withAlpha(150), fontSize: 13)),
                      ],
                    ),
                  ),
          ),
          // Gradient overlays
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withAlpha(100),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withAlpha(140),
                  ],
                  stops: const [0, 0.2, 0.7, 1],
                ),
              ),
            ),
          ),
          // Exercise name badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(120),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFaceExercise(widget.exercise.name)
                        ? Icons.face_rounded
                        : Icons.fitness_center_rounded,
                    color: AppColors.secondary,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.exercise.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Camera toggle
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.black.withAlpha(120),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _toggleCameraPower,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    _isCameraOff
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // Status & guidance at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(200),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status text
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(snapshot.statusText).withAlpha(40),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(snapshot.statusText).withAlpha(80),
                      ),
                    ),
                    child: Text(
                      snapshot.statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _getStatusColor(snapshot.statusText),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  // Camera guidance hint
                  if (hasGuidance) ...[
                    const SizedBox(height: 6),
                    Text(
                      snapshot.guidanceHint!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('Good') || status.contains('Done') || status.contains('rep')) {
      return AppColors.secondary;
    }
    if (status.contains('not visible') || status.contains('Move') || status.contains('Step')) {
      return AppColors.warning;
    }
    if (status.contains('Calibrating')) {
      return Colors.cyanAccent;
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
