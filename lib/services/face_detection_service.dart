import 'package:google_ml_kit/google_ml_kit.dart';

class FaceDetectionService {
  FaceDetector? _faceDetector;

  // Initialize face detector with custom options
  Future<void> initialize() async {
    try {
      final options = FaceDetectorOptions(
        enableContours: true, // Enable face contours
        enableLandmarks: true, // Enable face landmarks (eyes, nose, mouth)
        enableClassification: true, // Enable smile and eyes open classification
        enableTracking: true, // Enable face tracking
        minFaceSize: 0.1, // Minimum face size (10% of image)
        performanceMode:
            FaceDetectorMode.accurate, // Prioritize accuracy over speed
      );

      _faceDetector = GoogleMlKit.vision.faceDetector(options);
      print('Face detection service initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize face detection service: $e');
    }
  }

  // Detect faces in an image
  Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      if (_faceDetector == null) {
        throw Exception('Face detector not initialized');
      }

      final faces = await _faceDetector!.processImage(inputImage);
      print('Detected ${faces.length} faces');

      return faces;
    } catch (e) {
      throw Exception('Failed to detect faces: $e');
    }
  }

  // Get detailed face information
  Map<String, dynamic> getFaceInfo(Face face) {
    try {
      Map<String, dynamic> faceInfo = {
        // Bounding box
        'boundingBox': {
          'left': face.boundingBox.left,
          'top': face.boundingBox.top,
          'width': face.boundingBox.width,
          'height': face.boundingBox.height,
        },

        // Head rotation angles
        'headEulerAngleX': face.headEulerAngleX, // Pitch
        'headEulerAngleY': face.headEulerAngleY, // Yaw
        'headEulerAngleZ': face.headEulerAngleZ, // Roll
        // Tracking ID (if tracking is enabled)
        'trackingId': face.trackingId,
      };

      // Landmarks (if available)
      if (face.landmarks.isNotEmpty) {
        Map<String, Map<String, double>> landmarks = {};

        face.landmarks.forEach((landmarkType, landmark) {
          if (landmark != null) {
            landmarks[landmarkType.toString()] = {
              'x': landmark.position.x.toDouble(),
              'y': landmark.position.y.toDouble(),
            };
          }
        });

        faceInfo['landmarks'] = landmarks;
      }

      // Classifications (if available)
      if (face.smilingProbability != null) {
        faceInfo['smilingProbability'] = face.smilingProbability;
      }

      if (face.leftEyeOpenProbability != null) {
        faceInfo['leftEyeOpenProbability'] = face.leftEyeOpenProbability;
      }

      if (face.rightEyeOpenProbability != null) {
        faceInfo['rightEyeOpenProbability'] = face.rightEyeOpenProbability;
      }

      // Contours (if available)
      if (face.contours.isNotEmpty) {
        Map<String, List<Map<String, double>>> contours = {};

        face.contours.forEach((contourType, contour) {
          if (contour != null) {
            contours[contourType.toString()] = contour.points
                .map(
                  (point) => {'x': point.x.toDouble(), 'y': point.y.toDouble()},
                )
                .toList();
          }
        });

        faceInfo['contours'] = contours;
      }

      return faceInfo;
    } catch (e) {
      throw Exception('Failed to get face info: $e');
    }
  }

  // Check if face is suitable for attendance (quality checks)
  bool isFaceSuitableForAttendance(Face face) {
    try {
      // Check if face is too small
      double faceArea = face.boundingBox.width * face.boundingBox.height;
      if (faceArea < 10000) {
        // Minimum face area
        return false;
      }

      // Check head rotation angles (face should be relatively straight)
      if (face.headEulerAngleY != null && face.headEulerAngleY!.abs() > 30) {
        return false; // Too much yaw (left/right rotation)
      }

      if (face.headEulerAngleX != null && face.headEulerAngleX!.abs() > 20) {
        return false; // Too much pitch (up/down rotation)
      }

      // Check if eyes are open (if classification is available)
      if (face.leftEyeOpenProbability != null &&
          face.leftEyeOpenProbability! < 0.5) {
        return false; // Left eye likely closed
      }

      if (face.rightEyeOpenProbability != null &&
          face.rightEyeOpenProbability! < 0.5) {
        return false; // Right eye likely closed
      }

      return true;
    } catch (e) {
      print('Error checking face suitability: $e');
      return false;
    }
  }

  // Calculate face quality score (0.0 to 1.0)
  double calculateFaceQuality(Face face) {
    try {
      double score = 0.0;
      int factors = 0;

      // Factor 1: Face size (larger faces get higher scores)
      double faceArea = face.boundingBox.width * face.boundingBox.height;
      double sizeScore = (faceArea / 50000).clamp(
        0.0,
        1.0,
      ); // Normalize to max 50k pixels
      score += sizeScore;
      factors++;

      // Factor 2: Head pose (straighter faces get higher scores)
      if (face.headEulerAngleY != null) {
        double yawScore =
            1.0 - (face.headEulerAngleY!.abs() / 90.0).clamp(0.0, 1.0);
        score += yawScore;
        factors++;
      }

      if (face.headEulerAngleX != null) {
        double pitchScore =
            1.0 - (face.headEulerAngleX!.abs() / 90.0).clamp(0.0, 1.0);
        score += pitchScore;
        factors++;
      }

      // Factor 3: Eye openness
      if (face.leftEyeOpenProbability != null) {
        score += face.leftEyeOpenProbability!;
        factors++;
      }

      if (face.rightEyeOpenProbability != null) {
        score += face.rightEyeOpenProbability!;
        factors++;
      }

      // Return average score
      return factors > 0 ? score / factors : 0.0;
    } catch (e) {
      print('Error calculating face quality: $e');
      return 0.0;
    }
  }

  // Get the best face from multiple detected faces
  Face? getBestFace(List<Face> faces) {
    if (faces.isEmpty) return null;

    Face? bestFace;
    double bestScore = 0.0;

    for (Face face in faces) {
      if (isFaceSuitableForAttendance(face)) {
        double quality = calculateFaceQuality(face);
        if (quality > bestScore) {
          bestScore = quality;
          bestFace = face;
        }
      }
    }

    return bestFace;
  }

  // Dispose resources
  void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
    print('Face detection service disposed');
  }

  // Check if service is initialized
  bool get isInitialized => _faceDetector != null;
}
