# Face Attendance Flutter App

Aplikasi absensi menggunakan teknologi pengenalan wajah (face recognition) yang dibangun dengan Flutter, Firebase, dan Google ML Kit.

## Fitur Utama

### 🔥 Firebase Integration
- **Firebase Core**: Inisialisasi Firebase untuk backend services
- **Cloud Firestore**: Penyimpanan data absensi dan informasi wajah
- **Real-time Database**: Sinkronisasi data secara real-time
- **Firebase Auth**: Autentikasi pengguna (opsional untuk ekspansi)

### 📱 Permission & Camera Management
- **Runtime Permissions**: Manajemen izin kamera secara dinamis
- **Camera Access**: Akses kamera depan/belakang untuk pengambilan foto
- **Camera Preview**: Preview real-time dari kamera
- **Image Capture**: Pengambilan foto untuk analisis wajah

### 🤖 Google ML Kit Face Detection
- **Face Detection**: Deteksi wajah secara real-time
- **Face Landmarks**: Deteksi titik-titik penting wajah (mata, hidung, mulut)
- **Face Contours**: Kontur wajah untuk analisis yang lebih detail
- **Face Classification**: Klasifikasi ekspresi dan status mata
- **Quality Assessment**: Penilaian kualitas wajah untuk akurasi absensi

## Struktur Aplikasi

```
lib/
├── main.dart                 # Entry point aplikasi
├── models/
│   └── attendance_record.dart    # Model data absensi
├── screens/
│   ├── home_screen.dart          # Layar utama
│   └── attendance_screen.dart    # Layar absensi
└── services/
    ├── firebase_service.dart     # Service Firebase/Firestore
    ├── camera_service.dart       # Service manajemen kamera
    └── face_detection_service.dart # Service deteksi wajah
```

## Setup dan Instalasi

### Prerequisites
1. Flutter SDK (versi 3.8.1+)
2. Android SDK (minimum API level 21)
3. Firebase project
4. Google Services configuration

### Langkah Setup

#### 1. Firebase Setup
1. Buat proyek baru di [Firebase Console](https://console.firebase.google.com/)
2. Tambahkan aplikasi Android ke proyek Firebase
3. Download file `google-services.json`
4. Letakkan file di `android/app/`
5. Aktifkan Firestore Database di Firebase Console

#### 2. Konfigurasi Android
File `android/app/build.gradle.kts` sudah dikonfigurasi dengan:
- Namespace: `com.example.flutter_application_8`
- Compile SDK: 36
- Target SDK: 36

#### 3. Dependencies
Dependencies utama yang digunakan:
```yaml
dependencies:
  firebase_core: ^2.15.1
  firebase_auth: ^4.9.0
  cloud_firestore: ^4.9.1
  permission_handler: ^11.0.1
  camera: ^0.10.5
  google_ml_kit: ^0.15.0
  google_mlkit_face_detection: ^0.7.0
  path_provider: ^2.1.1
  intl: ^0.18.1
```

#### 4. Permissions
Permissions yang diperlukan (sudah ditambahkan di AndroidManifest.xml):
- `CAMERA`: Akses kamera
- `INTERNET`: Koneksi internet untuk Firebase
- `WRITE_EXTERNAL_STORAGE`: Penyimpanan foto
- `READ_EXTERNAL_STORAGE`: Membaca foto

### Instalasi
```bash
# Clone repository atau copy files
cd flutter_application_8

# Install dependencies
flutter pub get

# Run aplikasi
flutter run
```

## Cara Penggunaan

### 1. Home Screen
- Tampilan utama dengan opsi Check In dan Check Out
- Status koneksi Firebase dan sistem
- Navigasi ke layar absensi

### 2. Check In/Check Out
- Pilih mode Check In atau Check Out
- Kamera akan terbuka secara otomatis
- Posisikan wajah di dalam frame
- Tekan tombol untuk capture dan proses absensi
- Sistem akan mendeteksi wajah dan menyimpan data

### 3. Face Detection Process
- Deteksi wajah real-time
- Validasi kualitas wajah (pose, ukuran, keterbukaan mata)
- Ekstraksi fitur wajah (landmarks, contours)
- Penyimpanan data ke Firebase

## Implementasi Teknis

### Firebase Service
```dart
// Menyimpan record absensi
await FirebaseService.saveAttendanceRecord(record);

// Mengambil data absensi
List<AttendanceRecord> records = await FirebaseService.getAttendanceRecords(date);
```

### Camera Service
```dart
// Inisialisasi kamera
CameraController controller = await CameraService.initializeCamera();

// Capture gambar
String imagePath = await CameraService.captureImage(controller);
```

### Face Detection Service
```dart
// Deteksi wajah
List<Face> faces = await FaceDetectionService.detectFaces(inputImage);

// Analisis kualitas wajah
bool suitable = FaceDetectionService.isFaceSuitableForAttendance(face);
double quality = FaceDetectionService.calculateFaceQuality(face);
```

## Data Structure

### AttendanceRecord Model
```dart
class AttendanceRecord {
  final String id;
  final String userId;
  final String userName;
  final AttendanceType type; // checkIn or checkOut
  final DateTime timestamp;
  final String? photoPath;
  final Map<String, dynamic>? faceData;
  final double? confidence;
}
```

### Face Data Structure
```json
{
  "boundingBox": {
    "left": 100,
    "top": 150,
    "width": 200,
    "height": 250
  },
  "landmarks": {
    "leftEye": {"x": 150, "y": 200},
    "rightEye": {"x": 250, "y": 200},
    "nose": {"x": 200, "y": 250}
  },
  "headEulerAngleX": 5.2,
  "headEulerAngleY": -2.1,
  "headEulerAngleZ": 1.5,
  "smilingProbability": 0.8,
  "leftEyeOpenProbability": 0.9,
  "rightEyeOpenProbability": 0.85
}
```

## Konfigurasi Face Detection

### FaceDetectorOptions
```dart
final options = FaceDetectorOptions(
  enableContours: true,          // Kontour wajah
  enableLandmarks: true,         // Landmark wajah
  enableClassification: true,    // Klasifikasi ekspresi
  enableTracking: true,          // Tracking wajah
  minFaceSize: 0.1,             // Ukuran minimum wajah
  performanceMode: FaceDetectorMode.accurate, // Mode akurat
);
```

### Quality Assessment Parameters
- **Face Size**: Minimum 10.000 pixels
- **Head Pose**: Yaw < 30°, Pitch < 20°
- **Eye State**: Kedua mata terbuka (probability > 0.5)
- **Overall Quality**: Skor 0.0 - 1.0 berdasarkan kombinasi faktor

## Error Handling

### Common Issues & Solutions

1. **Firebase Connection Issues**
   - Pastikan `google-services.json` ada di `android/app/`
   - Periksa koneksi internet
   - Verifikasi konfigurasi Firebase

2. **Camera Permission Denied**
   - Request permission di runtime
   - Check AndroidManifest.xml permissions
   - Guide user untuk enable manual di settings

3. **Face Detection Failed**
   - Pastikan pencahayaan cukup
   - Posisi wajah menghadap kamera
   - Jarak yang tepat dari kamera

4. **ML Kit Namespace Issues**
   - Script otomatis sudah mengatasi masalah namespace
   - Jika error berlanjut, coba `flutter clean` dan `flutter pub get`

## Performance Optimization

### Tips untuk Performance Terbaik
1. **Camera Resolution**: Gunakan ResolutionPreset.medium untuk balance antara kualitas dan speed
2. **Face Detection**: Enable tracking untuk deteksi yang lebih smooth
3. **Memory Management**: Dispose camera controller dan face detector dengan benar
4. **Network Optimization**: Compress foto sebelum upload ke Firebase

## Security Considerations

### Data Privacy
- Foto wajah disimpan lokal sementara untuk processing
- Data biometrik tidak disimpan dalam bentuk raw
- Hanya fitur wajah (landmarks, measurements) yang disimpan
- Implementasi enkripsi untuk data sensitif (recommended)

### Authentication
- Struktur siap untuk implementasi Firebase Auth
- Role-based access control dapat ditambahkan
- Audit trail untuk semua aktivitas absensi

## Roadmap & Future Enhancements

### Planned Features
- [ ] Face Recognition untuk identifikasi otomatis
- [ ] Live face detection preview
- [ ] Offline mode dengan sync
- [ ] Admin dashboard
- [ ] Reports dan analytics
- [ ] Multi-language support
- [ ] Dark theme
- [ ] Biometric fallback (fingerprint)
- [ ] GPS location tracking
- [ ] Time-based attendance rules

### Technical Improvements
- [ ] Background processing
- [ ] Push notifications
- [ ] Improved error handling
- [ ] Unit tests coverage
- [ ] Integration tests
- [ ] Performance monitoring
- [ ] Crash reporting

## Contributing

Untuk berkontribusi pada proyek ini:
1. Fork repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## License

MIT License - lihat file LICENSE untuk detail lengkap.

## Support

Untuk bantuan dan support:
- Create issue di GitHub repository
- Email: support@faceattendance.com
- Documentation: [Wiki](link-to-wiki)

---

**Note**: Aplikasi ini adalah proof-of-concept untuk sistem absensi berbasis face detection. Untuk implementasi production, pertimbangkan aspek keamanan, privacy, dan compliance yang lebih ketat.
