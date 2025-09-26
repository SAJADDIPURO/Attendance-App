import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../models/attendance_record.dart';
import '../services/firebase_service.dart';
import '../widgets/export_report_widget.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceRecord> _attendanceRecords = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'All'; // All, Check In, Check Out

  @override
  void initState() {
    super.initState();
    _loadAttendanceRecords();
  }

  Future<void> _loadAttendanceRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<AttendanceRecord> records =
          await FirebaseService.getAttendanceRecords(_selectedDate);

      setState(() {
        _attendanceRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      _showErrorSnackBar('Failed to load attendance records: $e');
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo)),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadAttendanceRecords();
    }
  }

  List<AttendanceRecord> _getFilteredRecords() {
    if (_selectedFilter == 'All') {
      return _attendanceRecords;
    }

    AttendanceType filterType = _selectedFilter == 'Check In'
        ? AttendanceType.checkIn
        : AttendanceType.checkOut;

    return _attendanceRecords
        .where((record) => record.type == filterType)
        .toList();
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF232526),
          title: Row(
            children: [
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFF6a11cb)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.file_download, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 10),
              const Text('Export Attendance Data', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const SizedBox(
            width: double.maxFinite,
            child: ExportReportWidget(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showRecordDetails(AttendanceRecord record) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF232526),
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
              Text(
                record.type == AttendanceType.checkIn
                    ? 'Check In Details'
                    : 'Check Out Details',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('User', record.userName),
                _buildDetailRow(
                  'Time',
                  DateFormat('HH:mm:ss').format(record.timestamp),
                ),
                _buildDetailRow(
                  'Date',
                  DateFormat('EEEE, dd MMM yyyy').format(record.timestamp),
                ),
                if (record.confidence != null)
                  _buildDetailRow(
                    'Confidence',
                    '${(record.confidence! * 100).toStringAsFixed(1)}%',
                  ),
                const SizedBox(height: 16),

                if (record.photoPath != null &&
                    File(record.photoPath!).existsSync())
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Captured Photo:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
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

                if (record.faceData != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'Face Detection Data:',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      _buildFaceDataWidget(record.faceData!),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaceDataWidget(Map<String, dynamic> faceData) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: faceData.entries
            .map((e) => Text(
                  '${e.key}: ${e.value}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ))
            .toList(),
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
        title: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFF6a11cb)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(Icons.history, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            const Text(
              'Riwayat Absensi',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.white),
            tooltip: 'Export Data',
            onPressed: _showExportDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter & Date Picker
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF232526), Color(0xFF414345)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedFilter,
                    dropdownColor: const Color(0xFF232526),
                    iconEnabledColor: Colors.white,
                    items: const [
                      DropdownMenuItem(
                        value: 'All',
                        child: Text('Semua', style: TextStyle(color: Colors.white)),
                      ),
                      DropdownMenuItem(
                        value: 'Check In',
                        child: Text('Check In', style: TextStyle(color: Colors.white)),
                      ),
                      DropdownMenuItem(
                        value: 'Check Out',
                        child: Text('Check Out', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedFilter = val!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD700),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.date_range),
                  label: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                  onPressed: _selectDate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFFD700)),
                  )
                : _getFilteredRecords().isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada data absensi.',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _getFilteredRecords().length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final record = _getFilteredRecords()[index];
                          return GestureDetector(
                            onTap: () => _showRecordDetails(record),
                            child: Card(
                              color: const Color(0xFF232526),
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: record.type == AttendanceType.checkIn
                                      ? Colors.green
                                      : Colors.red,
                                  child: Icon(
                                    record.type == AttendanceType.checkIn
                                        ? Icons.login
                                        : Icons.logout,
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(
                                  record.userName,
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  DateFormat('EEEE, dd MMM yyyy • HH:mm:ss')
                                      .format(record.timestamp),
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                trailing: Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white54,
                                  size: 18,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}