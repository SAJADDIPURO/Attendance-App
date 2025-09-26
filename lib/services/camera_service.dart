import 'package:camera/camera.dart';
import 'dart:io';

class CameraService {
  static List<CameraDescription>? _cameras;

  // Initialize and get available cameras
  static Future<List<CameraDescription>> getAvailableCameras() async {
    _cameras ??= await availableCameras();
    return _cameras!;
  }

  // Initialize camera controller
  Future<CameraController> initializeCamera() async {
    try {
      // Get available cameras
      final cameras = await getAvailableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      // Prefer front camera for face detection
      CameraDescription selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Create camera controller
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false, // We don't need audio for attendance
        imageFormatGroup: ImageFormatGroup.nv21, // Good for Android ML Kit
      );

      return controller;
    } catch (e) {
      throw Exception('Failed to initialize camera: $e');
    }
  }

  // Get camera controller with specific resolution
  Future<CameraController> initializeCameraWithResolution(
    ResolutionPreset resolution,
  ) async {
    try {
      final cameras = await getAvailableCameras();

      if (cameras.isEmpty) {
        throw Exception('No cameras available');
      }

      CameraDescription selectedCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      return controller;
    } catch (e) {
      throw Exception('Failed to initialize camera with resolution: $e');
    }
  }

  // Switch between front and back camera
  Future<CameraController> switchCamera(
    CameraController currentController,
  ) async {
    try {
      final cameras = await getAvailableCameras();

      if (cameras.length < 2) {
        throw Exception('Only one camera available');
      }

      // Find the opposite camera
      CameraLensDirection currentDirection =
          currentController.description.lensDirection;
      CameraLensDirection newDirection =
          currentDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;

      CameraDescription newCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == newDirection,
      );

      // Dispose current controller
      await currentController.dispose();

      // Create new controller
      final newController = CameraController(
        newCamera,
        currentController.resolutionPreset,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      return newController;
    } catch (e) {
      throw Exception('Failed to switch camera: $e');
    }
  }

  // Capture image and return file path - DIPERBAIKI
  static Future<String> captureImage(CameraController controller) async {
    try {
      if (!controller.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      if (controller.value.isTakingPicture) {
        throw Exception('Camera is already taking a picture');
      }

      // Pastikan camera siap untuk mengambil gambar

      final XFile picture = await controller.takePicture();

      // Pastikan file gambar benar-benar ada
      if (await File(picture.path).exists()) {
        return picture.path;
      } else {
        throw Exception('Captured image file does not exist');
      }
    } catch (e) {
      throw Exception('Failed to capture image: $e');
    }
  }

  // Check if camera permission is granted
  static Future<bool> checkCameraPermission() async {
    try {
      final cameras = await availableCameras();
      return cameras.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get camera info
  static Future<Map<String, dynamic>> getCameraInfo() async {
    try {
      final cameras = await getAvailableCameras();

      return {
        'totalCameras': cameras.length,
        'hasFrontCamera': cameras.any(
          (c) => c.lensDirection == CameraLensDirection.front,
        ),
        'hasBackCamera': cameras.any(
          (c) => c.lensDirection == CameraLensDirection.back,
        ),
        'cameras': cameras
            .map(
              (c) => {
                'name': c.name,
                'lensDirection': c.lensDirection.toString(),
                'sensorOrientation': c.sensorOrientation,
              },
            )
            .toList(),
      };
    } catch (e) {
      throw Exception('Failed to get camera info: $e');
    }
  }
}
