import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:math';

import '../models/attendance_record.dart';
import '../services/firebase_service.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';

enum AttendanceMode { checkIn, checkOut }

class AttendanceScreen extends StatefulWidget {
  final AttendanceMode mode;

  const AttendanceScreen({super.key, required this.mode});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  List<Face> _detectedFaces = [];

  final CameraService _cameraService = CameraService();
  final FaceDetectionService _faceDetectionService = FaceDetectionService();

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Request camera permission
      await _requestCameraPermission();

      // Initialize face detection service
      await _faceDetectionService.initialize();

      // Initialize camera
      await _initializeCamera();
    } catch (e) {
      print('Error initializing services: $e');
      _showErrorDialog('Initialization Error', e.toString());
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.status;
    if (!status.isGranted) {
      final result = await Permission.camera.request();
      if (!result.isGranted) {
        throw Exception('Camera permission denied');
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameraController = await _cameraService.initializeCamera();

      await _cameraController!.initialize();

      // Tunggu sampai camera benar-benar siap
      await _cameraController!.lockCaptureOrientation();

      // Debug info
      print('Camera controller value: ${_cameraController?.value}');
      print('Camera initialized: ${_cameraController?.value.isInitialized}');
      print('Camera preview size: ${_cameraController?.value.previewSize}');

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      _showErrorDialog('Camera Error', 'Failed to initialize camera: $e');
    }
  }

  Future<void> _captureAndProcessImage() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Pastikan camera siap

      // Capture image menggunakan CameraService - DIPERBAIKI
      final imagePath = await CameraService.captureImage(_cameraController!);

      // Debug: print path untuk memastikan gambar diambil
      print('Image captured at: $imagePath');

      // Periksa apakah file gambar ada
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Captured image file does not exist');
      }

      // Process image for face detection
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetectionService.detectFaces(inputImage);

      setState(() {
        _detectedFaces = faces;
      });

      if (faces.isNotEmpty) {
        // Face detected, proceed with attendance
        await _processAttendance(imagePath, faces.first);
      } else {
        _showMessage(
          'No face detected',
          'Please ensure your face is clearly visible in the camera.',
        );
      }
    } catch (e) {
      print('Error capturing and processing image: $e');
      _showErrorDialog('Processing Error', e.toString());
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _processAttendance(String imagePath, Face face) async {
    try {
      // Create unique ID for this attendance record
      String recordId = '${DateTime.now().millisecondsSinceEpoch}';

      // For demo purposes, we'll use a dummy user ID
      // In a real app, you'd implement face recognition to identify the user
      String userId = 'user_${Random().nextInt(1000)}';
      String userName = 'Employee ${Random().nextInt(100)}';

      // Calculate confidence based on face detection confidence
      double confidence = face.headEulerAngleY != null
          ? (1.0 - (face.headEulerAngleY!.abs() / 90.0))
          : 0.8;

      // Get detailed face information
      Map<String, dynamic> faceData = _faceDetectionService.getFaceInfo(face);

      // Create attendance record
      AttendanceRecord record = AttendanceRecord(
        id: recordId,
        userId: userId,
        userName: userName,
        type: widget.mode == AttendanceMode.checkIn
            ? AttendanceType.checkIn
            : AttendanceType.checkOut,
        timestamp: DateTime.now(),
        photoPath: imagePath,
        faceData: faceData,
        confidence: confidence,
      );

      // Save to Firebase
      bool success = await FirebaseService.saveAttendanceRecord(record);

      if (success) {
        _showSuccessDialog(record);
      } else {
        _showMessage(
          'Save Failed',
          'Failed to save attendance record. Please try again.',
        );
      }
    } catch (e) {
      print('Error processing attendance: $e');
      _showErrorDialog('Attendance Error', e.toString());
    }
  }

  void _showSuccessDialog(AttendanceRecord record) {
    String typeText = record.type == AttendanceType.checkIn
        ? 'Check In'
        : 'Check Out';
    String timeText = DateFormat('HH:mm:ss').format(record.timestamp);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                record.type == AttendanceType.checkIn
                    ? Icons.login
                    : Icons.logout,
                color: record.type == AttendanceType.checkIn
                    ? Colors.green
                    : Colors.red,
              ),
              const SizedBox(width: 8),
              Text('$typeText Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${record.userName}'),
              Text('Time: $timeText'),
              Text(
                'Confidence: ${(record.confidence! * 100).toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 8),
              if (record.photoPath != null)
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(record.photoPath!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to home screen
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Text(title),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _faceDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String titleText = widget.mode == AttendanceMode.checkIn
        ? 'Check In'
        : 'Check Out';
    Color themeColor = widget.mode == AttendanceMode.checkIn
        ? Colors.green
        : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: _isCameraInitialized ? _buildCameraView() : _buildLoadingView(),
      floatingActionButton: _isCameraInitialized && !_isProcessing
          ? FloatingActionButton.extended(
              onPressed: _captureAndProcessImage,
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.camera),
              label: Text(titleText),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Initializing camera and face detection...',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraView() {
    final screenSize = MediaQuery.of(context).size;
    final camera = _cameraController!.value;

    // Get the preview size
    final previewSize = camera.previewSize;
    if (previewSize == null ||
        previewSize.height == 0 ||
        previewSize.width == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    // Calculate the scale to fit the screen
    final scale = max(
      screenSize.width / previewSize.height,
      screenSize.height / previewSize.width,
    );

    return Stack(
      children: [
        // Camera preview dengan aspect ratio yang benar
        Center(
          child: SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.height,
                height: previewSize.width,
                child: CameraPreview(_cameraController!),
              ),
            ),
          ),
        ),

        // Face detection overlay
        ..._detectedFaces
            .map((face) => _buildFaceOverlay(face, scale))
            ,

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),

        // Instructions overlay
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Position your face in the camera view and tap the ${widget.mode == AttendanceMode.checkIn ? 'Check In' : 'Check Out'} button',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaceOverlay(Face face, double scale) {
    final rect = face.boundingBox;
    final scaledLeft = rect.left * scale;
    final scaledTop = rect.top * scale;
    final scaledWidth = rect.width * scale;
    final scaledHeight = rect.height * scale;

    return Positioned(
      left: scaledLeft,
      top: scaledTop,
      width: scaledWidth,
      height: scaledHeight,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Confidence indicator
            Positioned(
              top: -25,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Face Detected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
