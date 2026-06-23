package com.adithya.glowup

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Rect
import android.graphics.YuvImage
import android.graphics.Matrix
import android.util.Log
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.facelandmarker.FaceLandmarker
import com.google.mediapipe.tasks.vision.poselandmarker.PoseLandmarker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val mediapipeChannel = "glowup/mediapipe"
    private val TAG = "GlowUpMediaPipe"

    private var faceLandmarker: FaceLandmarker? = null
    private var poseLandmarker: PoseLandmarker? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediapipeChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "processFrame") {
                    try {
                        val bytes = call.argument<ByteArray>("bytes")!!
                        val width = call.argument<Int>("width")!!
                        val height = call.argument<Int>("height")!!
                        val rotation = call.argument<Int>("rotation") ?: 0
                        val useFaceMesh = call.argument<Boolean>("useFaceMesh") ?: false
                        val usePose = call.argument<Boolean>("usePose") ?: false

                        val bitmap = yuvToBitmap(bytes, width, height, rotation)
                        if (bitmap == null) {
                            Log.e(TAG, "Failed to convert YUV to Bitmap")
                            result.success(
                                mapOf(
                                    "poseLandmarks" to emptyList<Map<String, Any>>(),
                                    "faceLandmarks" to emptyList<Map<String, Any>>()
                                )
                            )
                            return@setMethodCallHandler
                        }

                        val mpImage = BitmapImageBuilder(bitmap).build()

                        var faceLandmarksList = emptyList<Map<String, Any>>()
                        var poseLandmarksList = emptyList<Map<String, Any>>()

                        if (useFaceMesh) {
                            val landmarker = getOrCreateFaceLandmarker()
                            if (landmarker != null) {
                                try {
                                    val faceResult = landmarker.detect(mpImage)
                                    if (faceResult.faceLandmarks().isNotEmpty()) {
                                        val landmarks = faceResult.faceLandmarks()[0]
                                        faceLandmarksList = landmarks.mapIndexed { index, lm ->
                                            mapOf<String, Any>(
                                                "id" to index,
                                                "x" to lm.x().toDouble(),
                                                "y" to lm.y().toDouble(),
                                                "z" to lm.z().toDouble(),
                                                "visibility" to 1.0
                                            )
                                        }
                                    }
                                    Log.d(TAG, "Face detection: ${faceLandmarksList.size} landmarks")
                                } catch (e: Exception) {
                                    Log.e(TAG, "Face detection error: ${e.message}")
                                }
                            }
                        }

                        if (usePose) {
                            val landmarker = getOrCreatePoseLandmarker()
                            if (landmarker != null) {
                                try {
                                    val poseResult = landmarker.detect(mpImage)
                                    if (poseResult.landmarks().isNotEmpty()) {
                                        val landmarks = poseResult.landmarks()[0]
                                        poseLandmarksList = landmarks.mapIndexed { index, lm ->
                                            mapOf<String, Any>(
                                                "id" to index,
                                                "x" to lm.x().toDouble(),
                                                "y" to lm.y().toDouble(),
                                                "z" to lm.z().toDouble(),
                                                "visibility" to (lm.visibility()
                                                    .orElse(1.0f)).toDouble()
                                            )
                                        }
                                    }
                                    Log.d(TAG, "Pose detection: ${poseLandmarksList.size} landmarks")
                                } catch (e: Exception) {
                                    Log.e(TAG, "Pose detection error: ${e.message}")
                                }
                            }
                        }

                        bitmap.recycle()

                        result.success(
                            mapOf(
                                "poseLandmarks" to poseLandmarksList,
                                "faceLandmarks" to faceLandmarksList
                            )
                        )
                    } catch (e: Exception) {
                        Log.e(TAG, "processFrame error: ${e.message}", e)
                        result.success(
                            mapOf(
                                "poseLandmarks" to emptyList<Map<String, Any>>(),
                                "faceLandmarks" to emptyList<Map<String, Any>>()
                            )
                        )
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun getOrCreateFaceLandmarker(): FaceLandmarker? {
        if (faceLandmarker != null) return faceLandmarker

        return try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("face_landmarker.task")
                .build()

            val options = FaceLandmarker.FaceLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setNumFaces(1)
                .setMinFaceDetectionConfidence(0.5f)
                .setMinFacePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setRunningMode(com.google.mediapipe.tasks.vision.core.RunningMode.IMAGE)
                .build()

            faceLandmarker = FaceLandmarker.createFromOptions(this, options)
            Log.d(TAG, "FaceLandmarker initialized successfully")
            faceLandmarker
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create FaceLandmarker: ${e.message}", e)
            null
        }
    }

    private fun getOrCreatePoseLandmarker(): PoseLandmarker? {
        if (poseLandmarker != null) return poseLandmarker

        return try {
            val baseOptions = BaseOptions.builder()
                .setModelAssetPath("pose_landmarker_lite.task")
                .build()

            val options = PoseLandmarker.PoseLandmarkerOptions.builder()
                .setBaseOptions(baseOptions)
                .setNumPoses(1)
                .setMinPoseDetectionConfidence(0.5f)
                .setMinPosePresenceConfidence(0.5f)
                .setMinTrackingConfidence(0.5f)
                .setRunningMode(com.google.mediapipe.tasks.vision.core.RunningMode.IMAGE)
                .build()

            poseLandmarker = PoseLandmarker.createFromOptions(this, options)
            Log.d(TAG, "PoseLandmarker initialized successfully")
            poseLandmarker
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create PoseLandmarker: ${e.message}", e)
            null
        }
    }

    /**
     * Converts YUV420 camera frame bytes into a rotated ARGB Bitmap.
     *
     * Flutter's camera plugin sends YUV420 planes concatenated as a single byte array.
     * We reconstruct NV21 format (Y plane followed by interleaved VU) which Android's
     * YuvImage can handle, then compress to JPEG and decode to Bitmap.
     */
    private fun yuvToBitmap(bytes: ByteArray, width: Int, height: Int, rotation: Int): Bitmap? {
        return try {
            val ySize = width * height
            val uvSize = width * height / 4

            // The Flutter camera plugin sends planes as: Y | U | V
            // NV21 format expects: Y | VU (interleaved)
            val nv21 = ByteArray(ySize + ySize / 2)

            // Copy Y plane
            System.arraycopy(bytes, 0, nv21, 0, ySize)

            // Check if we have enough data for UV planes
            if (bytes.size >= ySize + 2 * uvSize) {
                // Interleave V and U planes into NV21 VU format
                val uOffset = ySize
                val vOffset = ySize + uvSize
                var nv21Offset = ySize
                for (i in 0 until uvSize) {
                    nv21[nv21Offset++] = bytes[vOffset + i] // V
                    nv21[nv21Offset++] = bytes[uOffset + i] // U
                }
            } else {
                // Fallback: If we have fewer bytes, treat as NV21 directly
                val remaining = minOf(bytes.size - ySize, ySize / 2)
                if (remaining > 0) {
                    System.arraycopy(bytes, ySize, nv21, ySize, remaining)
                }
            }

            val yuvImage = YuvImage(nv21, ImageFormat.NV21, width, height, null)
            val out = ByteArrayOutputStream()
            yuvImage.compressToJpeg(Rect(0, 0, width, height), 85, out)
            val jpegBytes = out.toByteArray()

            var bitmap = BitmapFactory.decodeByteArray(jpegBytes, 0, jpegBytes.size)

            // Apply rotation if needed
            if (rotation != 0 && bitmap != null) {
                val matrix = Matrix()
                matrix.postRotate(rotation.toFloat())
                val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
                if (rotated != bitmap) {
                    bitmap.recycle()
                }
                bitmap = rotated
            }

            bitmap
        } catch (e: Exception) {
            Log.e(TAG, "YUV to Bitmap conversion failed: ${e.message}", e)
            null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            faceLandmarker?.close()
            poseLandmarker?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing landmarkers: ${e.message}")
        }
        faceLandmarker = null
        poseLandmarker = null
    }
}
