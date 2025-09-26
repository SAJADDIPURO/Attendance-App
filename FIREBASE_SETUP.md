# Firebase Setup Instructions for Face Attendance App

## 1. Membuat Proyek Firebase

1. Buka [Firebase Console](https://console.firebase.google.com/)
2. Klik "Create a project" atau "Add project"
3. Masukkan nama proyek: `face-attendance-app`
4. Enable/disable Google Analytics sesuai kebutuhan
5. Pilih Google Analytics account (jika enabled)
6. Klik "Create project"

## 2. Menambahkan Aplikasi Android

1. Di dashboard Firebase, klik ikon Android
2. Isi form dengan informasi berikut:
   - **Android package name**: `com.example.flutter_application_8`
   - **App nickname**: `Face Attendance`
   - **Debug signing certificate SHA-1**: (opsional untuk development)

3. Klik "Register app"

## 3. Download Konfigurasi

1. Download file `google-services.json`
2. Copy file tersebut ke folder: `android/app/google-services.json`
3. Pastikan file berada di lokasi yang benar

## 4. Setup Firestore Database

1. Di Firebase Console, pilih "Firestore Database"
2. Klik "Create database"
3. Pilih mode:
   - **Test mode** (untuk development): Rules terbuka selama 30 hari
   - **Production mode**: Rules terbatas (direkomendasikan untuk production)

4. Pilih lokasi server (pilih yang terdekat dengan user)
5. Klik "Done"

## 5. Firestore Security Rules

Untuk development, gunakan rules berikut (permissive):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access to all documents
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

Untuk production, gunakan rules yang lebih ketat:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Attendance records
    match /attendance/{recordId} {
      allow read, write: if request.auth != null;
    }
    
    // Face encodings
    match /face_encodings/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

## 6. Firestore Collections Structure

### Collection: `attendance`
```json
{
  "id": "string",
  "userId": "string", 
  "userName": "string",
  "type": "checkIn" | "checkOut",
  "timestamp": "timestamp",
  "photoPath": "string",
  "faceData": {
    "boundingBox": {
      "left": "number",
      "top": "number", 
      "width": "number",
      "height": "number"
    },
    "landmarks": "object",
    "headEulerAngleX": "number",
    "headEulerAngleY": "number",
    "headEulerAngleZ": "number",
    "smilingProbability": "number",
    "leftEyeOpenProbability": "number",
    "rightEyeOpenProbability": "number"
  },
  "confidence": "number"
}
```

### Collection: `face_encodings`
```json
{
  "userId": "string",
  "userName": "string", 
  "faceEncoding": "array",
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## 7. Firebase Authentication (Opsional)

Jika ingin menambahkan autentikasi:

1. Di Firebase Console, pilih "Authentication"
2. Klik "Get started"
3. Pilih sign-in methods:
   - Email/Password
   - Google
   - Anonymous (untuk demo)

4. Configure sesuai kebutuhan

## 8. Firebase Storage (Opsional)

Untuk menyimpan foto:

1. Di Firebase Console, pilih "Storage"
2. Klik "Get started"
3. Configure security rules untuk storage

## 9. Testing Firebase Connection

Setelah setup, test koneksi dengan:

```dart
void testFirebaseConnection() async {
  try {
    await Firebase.initializeApp();
    print('Firebase connected successfully');
    
    // Test Firestore
    await FirebaseFirestore.instance.collection('test').add({
      'message': 'Hello Firebase!',
      'timestamp': FieldValue.serverTimestamp(),
    });
    
    print('Firestore test successful');
  } catch (e) {
    print('Firebase error: $e');
  }
}
```

## 10. Troubleshooting

### Common Issues:

1. **`google-services.json` not found**
   - Pastikan file ada di `android/app/google-services.json`
   - Restart aplikasi setelah menambah file

2. **Firebase connection timeout**
   - Periksa koneksi internet
   - Verifikasi package name match dengan Firebase config

3. **Firestore permission denied**
   - Periksa security rules
   - Pastikan user sudah authenticated (jika menggunakan auth)

4. **Build error setelah menambah Firebase**
   - Run `flutter clean`
   - Run `flutter pub get`
   - Rebuild aplikasi

## 11. Environment Variables (Production)

Untuk production, consider menggunakan:

- Firebase App Distribution untuk testing
- Firebase Performance Monitoring
- Firebase Crashlytics untuk error tracking
- Firebase Remote Config untuk feature flags

## 12. Data Privacy Compliance

Pastikan compliance dengan:
- GDPR (untuk users di EU)
- Local data protection laws
- Company privacy policies

Implement:
- Data retention policies
- User consent management
- Data deletion capabilities
- Audit trails
