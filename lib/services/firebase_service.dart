// services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/attendance_record.dart';

class FirebaseService {
  static FirebaseFirestore? _firestore;
  static bool _isInitialized = false;
  static bool _isOfflineMode = false;
  static bool _hasPermissionError = false;
  static final List<AttendanceRecord> _localRecords = [];

  static FirebaseFirestore? get firestore => _firestore;
  static bool get isInitialized => _isInitialized;
  static bool get isOfflineMode => _isOfflineMode;
  static bool get hasPermissionError => _hasPermissionError;

  // Initialize Firebase services
  static Future<void> initialize() async {
    try {
      // Check if Firebase apps are available
      if (Firebase.apps.isNotEmpty) {
        _firestore = FirebaseFirestore.instance;

        // Configure Firestore settings BEFORE enabling persistence
        _firestore!.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );

        print('Firestore settings configured');

        // Test connection dengan timeout yang lebih panjang
        try {
          // Coba koneksi sederhana tanpa enable network dulu
          print('Testing Firebase connection...');

          // Test dengan operasi read sederhana dengan timeout lebih panjang
          await _firestore!
              .collection('attendance')
              .limit(1)
              .get(const GetOptions(source: Source.server))
              .timeout(const Duration(seconds: 15));

          _isInitialized = true;
          _isOfflineMode = false;
          _hasPermissionError = false;
          print('Firebase initialized successfully - ONLINE MODE');
        } catch (e) {
          print('Firebase connection test failed: $e');

          // Check specific error types
          if (e.toString().toLowerCase().contains('permission') ||
              e.toString().toLowerCase().contains('denied') ||
              e.toString().toLowerCase().contains('unauthorized')) {
            _hasPermissionError = true;
            print('Firebase permission error detected');
          }

          // Try to get cached data to confirm Firestore is working locally
          try {
            await _firestore!
                .collection('attendance')
                .limit(1)
                .get(const GetOptions(source: Source.cache));
            print('Cache access successful - enabling offline mode');
          } catch (cacheError) {
            print('Cache access failed: $cacheError');
          }

          _isInitialized = false;
          _isOfflineMode = true;
          print('Switched to OFFLINE MODE due to connection issues');
        }
      } else {
        throw Exception(
          'No Firebase apps found - check Firebase initialization in main.dart',
        );
      }
    } catch (e) {
      print('Firebase initialization failed completely: $e');
      _isInitialized = false;
      _isOfflineMode = true;
      _hasPermissionError = true;
    }
  }

  // Test Firebase connection explicitly
  static Future<bool> testConnection() async {
    try {
      if (_firestore == null) return false;

      print('Testing Firebase connection...');

      // Try to write and read a test document
      String testId = 'test_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore!
          .collection('connection_test')
          .doc(testId)
          .set({'timestamp': FieldValue.serverTimestamp(), 'test': true})
          .timeout(const Duration(seconds: 10));

      // Try to read it back
      DocumentSnapshot doc = await _firestore!
          .collection('connection_test')
          .doc(testId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 10));

      if (doc.exists) {
        // Clean up test document
        await _firestore!.collection('connection_test').doc(testId).delete();

        print('Firebase connection test successful');
        return true;
      }

      return false;
    } catch (e) {
      print('Firebase connection test failed: $e');
      return false;
    }
  }

  // Save attendance record with improved error handling
  static Future<bool> saveAttendanceRecord(AttendanceRecord record) async {
    try {
      // Always try to save locally first for reliability
      _localRecords.add(record);
      print('Attendance record saved locally: ${record.id}');

      // If we're in offline mode, don't attempt Firebase save
      if (_isOfflineMode || !_isInitialized) {
        print('Operating in offline mode - record saved locally only');
        return true;
      }

      // Try to save to Firebase
      try {
        await _firestore!
            .collection('attendance')
            .doc(record.id)
            .set(record.toMap())
            .timeout(const Duration(seconds: 15));

        print('Attendance record saved to Firebase: ${record.id}');

        // If successful, we can update our status
        _isOfflineMode = false;
        _hasPermissionError = false;

        return true;
      } catch (firebaseError) {
        print('Firebase save failed: $firebaseError');

        // Check if it's a permission error
        if (firebaseError.toString().toLowerCase().contains('permission') ||
            firebaseError.toString().toLowerCase().contains('denied')) {
          _hasPermissionError = true;
          _isOfflineMode = true;
          print('Permission error detected - switching to offline mode');
        } else {
          // Network or other error
          _isOfflineMode = true;
          print('Network error - switching to offline mode');
        }

        // Data is already saved locally, so still return true
        return true;
      }
    } catch (e) {
      print('Error saving attendance record: $e');

      // Ensure local save succeeded
      if (!_localRecords.any((r) => r.id == record.id)) {
        _localRecords.add(record);
      }

      return true; // Always return true since we have local fallback
    }
  }

  // Get attendance records with improved fallback
  static Future<List<AttendanceRecord>> getAttendanceRecords(
    DateTime date,
  ) async {
    List<AttendanceRecord> allRecords = [];

    // Always include local records
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    List<AttendanceRecord> localDateRecords = _localRecords
        .where(
          (record) =>
              record.timestamp.isAfter(startOfDay) &&
              record.timestamp.isBefore(endOfDay),
        )
        .toList();

    allRecords.addAll(localDateRecords);
    print(
      'Found ${localDateRecords.length} local records for ${date.toString().split(' ')[0]}',
    );

    // Try to get Firebase records if online
    if (!_isOfflineMode &&
        _isInitialized &&
        _firestore != null &&
        !_hasPermissionError) {
      try {
        print('Attempting to fetch Firebase records...');

        QuerySnapshot querySnapshot = await _firestore!
            .collection('attendance')
            .where(
              'timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
            )
            .where(
              'timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endOfDay),
            )
            .orderBy('timestamp', descending: true)
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 15));

        List<AttendanceRecord> firebaseRecords = querySnapshot.docs
            .map(
              (doc) =>
                  AttendanceRecord.fromMap(doc.data() as Map<String, dynamic>),
            )
            .toList();

        print('Found ${firebaseRecords.length} Firebase records');

        // Merge records, avoiding duplicates
        for (AttendanceRecord fbRecord in firebaseRecords) {
          if (!allRecords.any((record) => record.id == fbRecord.id)) {
            allRecords.add(fbRecord);
          }
        }
      } catch (e) {
        print('Failed to fetch Firebase records: $e');

        // Update offline status if needed
        if (e.toString().toLowerCase().contains('permission') ||
            e.toString().toLowerCase().contains('denied')) {
          _hasPermissionError = true;
          _isOfflineMode = true;
        }
      }
    }

    // Sort by timestamp (most recent first)
    allRecords.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return allRecords;
  }

  // Sync local records to Firebase when connection is restored
  static Future<int> syncLocalRecords() async {
    if (_isOfflineMode ||
        !_isInitialized ||
        _hasPermissionError ||
        _localRecords.isEmpty) {
      return 0;
    }

    int syncedCount = 0;
    List<AttendanceRecord> recordsToRemove = [];

    print('Attempting to sync ${_localRecords.length} local records...');

    for (AttendanceRecord record in _localRecords) {
      try {
        await _firestore!
            .collection('attendance')
            .doc(record.id)
            .set(record.toMap())
            .timeout(const Duration(seconds: 10));

        syncedCount++;
        recordsToRemove.add(record);
        print('Synced record: ${record.id}');
      } catch (e) {
        print('Failed to sync record ${record.id}: $e');
        // Stop syncing if we hit errors
        break;
      }
    }

    // Remove successfully synced records from local storage
    for (AttendanceRecord record in recordsToRemove) {
      _localRecords.remove(record);
    }

    print('Successfully synced $syncedCount records');
    return syncedCount;
  }

  // Get detailed sync status for debugging
  static Map<String, dynamic> getSyncStatus() {
    return {
      'initialized': _isInitialized,
      'offlineMode': _isOfflineMode,
      'hasPermissionError': _hasPermissionError,
      'localRecordsCount': _localRecords.length,
      'firebaseAppsCount': Firebase.apps.length,
      'lastSyncAttempt': DateTime.now().toString(),
    };
  }

  // Force reconnection attempt
  static Future<bool> attemptReconnection() async {
    try {
      print('Attempting to reconnect to Firebase...');

      _hasPermissionError = false;
      _isOfflineMode = false;

      bool connectionTest = await testConnection();

      if (connectionTest) {
        _isInitialized = true;
        _isOfflineMode = false;
        _hasPermissionError = false;

        // Try to sync local records
        await syncLocalRecords();

        print('Reconnection successful!');
        return true;
      } else {
        _isOfflineMode = true;
        print('Reconnection failed - staying in offline mode');
        return false;
      }
    } catch (e) {
      print('Reconnection attempt failed: $e');
      _isOfflineMode = true;
      return false;
    }
  }

  // Clear all local data (use with caution)
  static void clearLocalData() {
    _localRecords.clear();
    print('Local data cleared');
  }

  // Get all local records (for debugging)
  static List<AttendanceRecord> getLocalRecords() {
    return List.from(_localRecords);
  }
}
