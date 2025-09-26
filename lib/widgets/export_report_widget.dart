import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/attendance_record.dart';
import '../services/firebase_service.dart';

class ExportReportWidget extends StatefulWidget {
  const ExportReportWidget({super.key});

  @override
  State<ExportReportWidget> createState() => _ExportReportWidgetState();
}

class _ExportReportWidgetState extends State<ExportReportWidget> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isExporting = false;

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: _endDate,
    );

    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<List<AttendanceRecord>> _getAllRecordsInRange() async {
    List<AttendanceRecord> allRecords = [];
    DateTime currentDate = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    DateTime endDateOnly = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
    );

    while (currentDate.isBefore(endDateOnly.add(const Duration(days: 1)))) {
      try {
        List<AttendanceRecord> dayRecords =
            await FirebaseService.getAttendanceRecords(currentDate);
        allRecords.addAll(dayRecords);
      } catch (e) {
        print('Error loading records for $currentDate: $e');
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Sort by timestamp
    allRecords.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return allRecords;
  }

  Future<String> _generateCSVContent(List<AttendanceRecord> records) async {
    StringBuffer csv = StringBuffer();

    // CSV Header
    csv.writeln(
      'Date,Time,User ID,User Name,Type,Confidence,Face Data Available',
    );

    // CSV Data
    for (AttendanceRecord record in records) {
      String date = DateFormat('yyyy-MM-dd').format(record.timestamp);
      String time = DateFormat('HH:mm:ss').format(record.timestamp);
      String type = record.type == AttendanceType.checkIn
          ? 'Check In'
          : 'Check Out';
      String confidence = record.confidence != null
          ? '${(record.confidence! * 100).toStringAsFixed(1)}%'
          : 'N/A';
      String hasFaceData = record.faceData != null ? 'Yes' : 'No';

      csv.writeln(
        '$date,$time,${record.userId},${record.userName},$type,$confidence,$hasFaceData',
      );
    }

    return csv.toString();
  }

  Future<void> _exportToCSV() async {
    if (_isExporting) return;

    setState(() {
      _isExporting = true;
    });

    try {
      // Load records
      List<AttendanceRecord> records = await _getAllRecordsInRange();

      if (records.isEmpty) {
        _showMessage(
          'No Data',
          'No attendance records found in the selected date range.',
        );
        return;
      }

      // Generate CSV content
      String csvContent = await _generateCSVContent(records);

      // Get directory to save file
      Directory? directory;

      try {
        directory = await getExternalStorageDirectory();
        if (directory == null || !await directory.exists()) {
          directory = await getApplicationDocumentsDirectory();
        }
      } catch (e) {
        directory = await getApplicationDocumentsDirectory();
      }

      // Create filename with timestamp
      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      String dateRange =
          '${DateFormat('yyyyMMdd').format(_startDate)}_to_${DateFormat('yyyyMMdd').format(_endDate)}';
      String filename = 'attendance_report_${dateRange}_$timestamp.csv';

      // Write file
      File file = File('${directory.path}/$filename');
      await file.writeAsString(csvContent);

      // Show success dialog with file path
      _showExportSuccessDialog(file.path, records.length);
    } catch (e) {
      _showMessage('Export Error', 'Failed to export data: $e');
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _showExportSuccessDialog(String filePath, int recordCount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Export Successful'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exported $recordCount attendance records successfully.'),
              const SizedBox(height: 8),
              const Text(
                'File saved to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  filePath,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'You can find this file in your device\'s file manager or share it with other apps.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
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

  @override
  Widget build(BuildContext context) {
    int daysDifference = _endDate.difference(_startDate).inDays + 1;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.file_download, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Export Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'Select Date Range:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Date Range Selector
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _selectStartDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'From',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy').format(_startDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: GestureDetector(
                    onTap: _selectEndDate,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'To',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('dd MMM yyyy').format(_endDate),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Info
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, size: 16, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Will export $daysDifference day${daysDifference > 1 ? 's' : ''} of attendance data to CSV format',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Export Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportToCSV,
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.file_download),
                label: Text(_isExporting ? 'Exporting...' : 'Export to CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
