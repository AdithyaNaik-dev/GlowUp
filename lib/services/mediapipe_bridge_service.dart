import 'package:flutter/services.dart';

class LandmarkPoint {
  final int id;
  final double x;
  final double y;
  final double z;
  final double visibility;

  const LandmarkPoint({
    required this.id,
    required this.x,
    required this.y,
    this.z = 0,
    this.visibility = 1,
  });

  factory LandmarkPoint.fromMap(Map<dynamic, dynamic> map) {
    return LandmarkPoint(
      id: (map['id'] ?? 0) as int,
      x: ((map['x'] ?? 0) as num).toDouble(),
      y: ((map['y'] ?? 0) as num).toDouble(),
      z: ((map['z'] ?? 0) as num).toDouble(),
      visibility: ((map['visibility'] ?? 1) as num).toDouble(),
    );
  }
}

class MediapipeFrameResult {
  final List<LandmarkPoint> poseLandmarks;
  final List<LandmarkPoint> faceLandmarks;

  const MediapipeFrameResult({
    required this.poseLandmarks,
    required this.faceLandmarks,
  });

  factory MediapipeFrameResult.fromMap(Map<dynamic, dynamic> map) {
    final poseRaw = (map['poseLandmarks'] as List<dynamic>? ?? <dynamic>[]);
    final faceRaw = (map['faceLandmarks'] as List<dynamic>? ?? <dynamic>[]);

    return MediapipeFrameResult(
      poseLandmarks: poseRaw
          .map((e) => LandmarkPoint.fromMap(e as Map<dynamic, dynamic>))
          .toList(growable: false),
      faceLandmarks: faceRaw
          .map((e) => LandmarkPoint.fromMap(e as Map<dynamic, dynamic>))
          .toList(growable: false),
    );
  }
}

class MediapipeBridgeService {
  static const MethodChannel _channel = MethodChannel('glowup/mediapipe');

  Future<MediapipeFrameResult> processFrame({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rotation,
    required String exerciseName,
    required bool useFaceMesh,
    required bool usePose,
  }) async {
    try {
      final response = await _channel
          .invokeMapMethod<String, dynamic>('processFrame', <String, dynamic>{
            'bytes': bytes,
            'width': width,
            'height': height,
            'rotation': rotation,
            'exerciseName': exerciseName,
            'useFaceMesh': useFaceMesh,
            'usePose': usePose,
          });

      if (response == null) {
        return const MediapipeFrameResult(poseLandmarks: [], faceLandmarks: []);
      }

      return MediapipeFrameResult.fromMap(response);
    } on MissingPluginException {
      return const MediapipeFrameResult(poseLandmarks: [], faceLandmarks: []);
    } catch (e) {
      // Silently fail — MediaPipe may not be available on all devices
      return const MediapipeFrameResult(poseLandmarks: [], faceLandmarks: []);
    }
  }
}
