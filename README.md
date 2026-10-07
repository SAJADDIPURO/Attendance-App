# Face Attendance App

A mobile attendance app that uses **on-device face detection** to verify that a real face is present before recording attendance. Records are stored in Cloud Firestore.

## Features

- **Real-time face detection** with Google ML Kit: face landmarks (eyes, nose, mouth), contours, and classification (eye-open probability, smiling)
- **Face quality check** before saving, to reduce invalid check-ins
- **Camera management:** front/back camera, live preview, image capture
- **Runtime permission handling** for camera access
- **Cloud Firestore** for attendance records with timestamps
- **Firebase Auth** ready for user accounts

## Tech Stack

Flutter · Dart · Google ML Kit (Face Detection) · Firebase (Core, Auth, Cloud Firestore) · Camera plugin

## Project Structure

```
lib/
├── main.dart
├── models/attendance_record.dart
├── screens/        # home, attendance
└── services/       # firebase_service, camera_service, face_detection_service
```

## Getting Started

1. Install Flutter 3.8+ and the Android SDK (min API 21).
2. Create a Firebase project, add an Android app, and put your own `google-services.json` in `android/app/`.
3. Enable Cloud Firestore.
4. Run:
   ```bash
   flutter pub get
   flutter run
   ```

More guides: [QUICK_START.md](QUICK_START.md) · [FIREBASE_SETUP.md](FIREBASE_SETUP.md) · [CAMERA_TROUBLESHOOTING.md](CAMERA_TROUBLESHOOTING.md) · [USER_GUIDE.md](USER_GUIDE.md)

## What I Learned

Applying a computer vision model on mobile: interpreting face landmarks and classification probabilities to decide whether a capture is valid.
