import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../services/firebase_service.dart';

class DailySummaryWidget extends StatefulWidget {
  const DailySummaryWidget({super.key});

  @override
  State<DailySummaryWidget> createState() => _DailySummaryWidgetState();
}

class _DailySummaryWidgetState extends State<DailySummaryWidget> {
  List<AttendanceRecord> _todayRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTodayRecords();
  }

  Future<void> _loadTodayRecords() async {
    try {
      setState(() {
        _isLoading = true;
      });

      List<AttendanceRecord> records =
          await FirebaseService.getAttendanceRecords(DateTime.now());

      setState(() {
        _todayRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading today records: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFirstCheckInTime() {
    final checkIns =
        _todayRecords.where((r) => r.type == AttendanceType.checkIn).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (checkIns.isEmpty) return '--:--';
    return DateFormat('HH:mm').format(checkIns.first.timestamp);
  }

  String _getLastCheckOutTime() {
    final checkOuts =
        _todayRecords.where((r) => r.type == AttendanceType.checkOut).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (checkOuts.isEmpty) return '--:--';
    return DateFormat('HH:mm').format(checkOuts.first.timestamp);
  }

  int _getCheckInCount() {
    return _todayRecords.where((r) => r.type == AttendanceType.checkIn).length;
  }

  int _getCheckOutCount() {
    return _todayRecords.where((r) => r.type == AttendanceType.checkOut).length;
  }

  String _getWorkingHours() {
    final checkIns =
        _todayRecords.where((r) => r.type == AttendanceType.checkIn).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final checkOuts =
        _todayRecords.where((r) => r.type == AttendanceType.checkOut).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (checkIns.isEmpty || checkOuts.isEmpty) return '--h --m';

    final firstCheckIn = checkIns.first.timestamp;
    final lastCheckOut = checkOuts.first.timestamp;

    if (lastCheckOut.isBefore(firstCheckIn)) return '--h --m';

    final Duration workingTime = lastCheckOut.difference(firstCheckIn);
    final int hours = workingTime.inHours;
    final int minutes = workingTime.inMinutes % 60;

    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Today\'s Attendance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadTodayRecords,
                    iconSize: 20,
                  ),
              ],
            ),

            Text(
              DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),

            const SizedBox(height: 16),

            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Loading today\'s data...'),
                ),
              )
            else if (_todayRecords.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'No attendance records today',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  // Summary Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Check In',
                          _getCheckInCount().toString(),
                          Icons.login,
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Check Out',
                          _getCheckOutCount().toString(),
                          Icons.logout,
                          Colors.red,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Time Details
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildTimeInfo(
                              'First Check In',
                              _getFirstCheckInTime(),
                              Colors.green,
                            ),
                            _buildTimeInfo(
                              'Last Check Out',
                              _getLastCheckOutTime(),
                              Colors.red,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildTimeInfo(
                          'Working Hours',
                          _getWorkingHours(),
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),

                  // Recent Activity
                  if (_todayRecords.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Recent Activity:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _todayRecords.take(5).length,
                        itemBuilder: (context, index) {
                          final record = _todayRecords[index];
                          return Container(
                            width: 140,
                            margin: const EdgeInsets.only(right: 8),
                            child: _buildRecentActivityCard(record),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(
          time,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivityCard(AttendanceRecord record) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  record.type == AttendanceType.checkIn
                      ? Icons.login
                      : Icons.logout,
                  size: 16,
                  color: record.type == AttendanceType.checkIn
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    record.type == AttendanceType.checkIn ? 'In' : 'Out',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: record.type == AttendanceType.checkIn
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm:ss').format(record.timestamp),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Text(
              record.userName,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
