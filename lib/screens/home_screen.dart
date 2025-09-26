import 'package:flutter/material.dart';
import 'attendance_screen.dart';
import 'attendance_history_screen.dart';
import '../services/firebase_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _firebaseStatus = 'Initializing...';
  Color _firebaseStatusColor = Colors.orange;
  Map<String, dynamic> _syncStatus = {};
  bool _isReconnecting = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      setState(() {
        _isLoading = true;
        _firebaseStatus = 'Initializing Firebase...';
        _firebaseStatusColor = Colors.orange;
      });

      await FirebaseService.initialize();
      _syncStatus = FirebaseService.getSyncStatus();

      setState(() {
        _isLoading = false;
        _updateFirebaseStatus();
      });

      _testConnectionInBackground();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _firebaseStatus = 'Initialization Error';
        _firebaseStatusColor = Colors.red;
      });
    }
  }

  void _updateFirebaseStatus() {
    if (FirebaseService.hasPermissionError) {
      _firebaseStatus = 'Permission Denied';
      _firebaseStatusColor = Colors.red;
    } else if (FirebaseService.isInitialized) {
      _firebaseStatus = 'Online';
      _firebaseStatusColor = Colors.green;
    } else if (FirebaseService.isOfflineMode) {
      _firebaseStatus = 'Offline Mode';
      _firebaseStatusColor = Colors.orange;
    } else {
      _firebaseStatus = 'Disconnected';
      _firebaseStatusColor = Colors.red;
    }
  }

  Future<void> _testConnectionInBackground() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted && !FirebaseService.isInitialized) {
      bool connectionResult = await FirebaseService.testConnection();
      if (mounted) {
        setState(() {
          _syncStatus = FirebaseService.getSyncStatus();
          _updateFirebaseStatus();
        });
        if (connectionResult) {
          _showSnackBar('Connection restored!', Colors.green);
        }
      }
    }
  }

  Future<void> _attemptReconnection() async {
    setState(() {
      _isReconnecting = true;
      _firebaseStatus = 'Reconnecting...';
      _firebaseStatusColor = Colors.blue;
    });

    try {
      bool success = await FirebaseService.attemptReconnection();
      setState(() {
        _isReconnecting = false;
        _syncStatus = FirebaseService.getSyncStatus();
        _updateFirebaseStatus();
      });

      if (success) {
        _showSnackBar('Reconnection successful!', Colors.green);
      } else {
        _showSnackBar(
          'Reconnection failed. Check your internet connection.',
          Colors.red,
        );
      }
    } catch (e) {
      setState(() {
        _isReconnecting = false;
        _updateFirebaseStatus();
      });
      _showSnackBar('Reconnection error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSyncStatusDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sync Status Details'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStatusRow(
                  'Initialized',
                  _syncStatus['initialized']?.toString() ?? 'false',
                ),
                _buildStatusRow(
                  'Offline Mode',
                  _syncStatus['offlineMode']?.toString() ?? 'false',
                ),
                _buildStatusRow(
                  'Permission Error',
                  _syncStatus['hasPermissionError']?.toString() ?? 'false',
                ),
                _buildStatusRow(
                  'Local Records',
                  _syncStatus['localRecordsCount']?.toString() ?? '0',
                ),
                _buildStatusRow(
                  'Firebase Apps',
                  _syncStatus['firebaseAppsCount']?.toString() ?? '0',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Local Records:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${_syncStatus['localRecordsCount'] ?? 0} records stored locally',
                ),
                if (_syncStatus['localRecordsCount'] != null &&
                    _syncStatus['localRecordsCount'] > 0)
                  const Text(
                    'These will sync when connection is restored.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            if (!FirebaseService.isInitialized)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _attemptReconnection();
                },
                child: const Text('Retry Connection'),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF232526),
        elevation: 0,
        title: const Text(
          'Face Attendance',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Kembali ke Login',
            onPressed: () {
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: _isLoading ? _buildLoadingScreen() : _buildMainContent(),
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Initializing services...', style: TextStyle(fontSize: 16, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header Gradient & Avatar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 48, bottom: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF232526),
                  Color(0xFF414345),
                  Color(0xFF6a11cb),
                  Color(0xFF2575fc)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Color(0xFF232526),
                  child: Icon(Icons.face, size: 48, color: Color(0xFFFFD700)), // Gold accent
                ),
                const SizedBox(height: 16),
                const Text(
                  'Face Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _firebaseStatus,
                  style: TextStyle(
                    color: _firebaseStatusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.white),
                  onPressed: _showSyncStatusDialog,
                  tooltip: 'Show detailed status',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Welcome Card
          Card(
            color: const Color(0xFF232526),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Text(
                    'Selamat Datang!',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Absen lebih mudah dan aman dengan teknologi pengenalan wajah.',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AttendanceScreen(mode: AttendanceMode.checkIn),
                        ),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Check In', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFD700), // Gold
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AttendanceScreen(mode: AttendanceMode.checkOut),
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Check Out', style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6a11cb), // Ungu elegan
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AttendanceHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history),
              label: const Text('Riwayat Absensi', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Tombol kembali ke halaman login
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26.0),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/login');
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('Keluar / Kembali ke Login', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF414345),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Status Card
          Card(
            color: const Color(0xFF414345),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFF6a11cb)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Status Sistem',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStatusItem('Firebase', _firebaseStatus, _firebaseStatusColor, icon: Icons.cloud),
                  _buildStatusItem('Kamera', 'Ready', Colors.greenAccent, icon: Icons.camera_alt_rounded),
                  _buildStatusItem('ML Kit', 'Ready', Colors.greenAccent, icon: Icons.memory_rounded),
                  if (_syncStatus['localRecordsCount'] != null &&
                      _syncStatus['localRecordsCount'] > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storage,
                              size: 16,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_syncStatus['localRecordsCount']} records stored locally',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String status, Color color, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (icon != null)
                Icon(icon, color: Colors.white, size: 20),
              if (icon != null)
                const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white)),
            ],
          ),
          Text(
            status,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}