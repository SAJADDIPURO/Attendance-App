import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/attendance_record.dart';
import '../services/firebase_service.dart';

class AttendanceSummaryScreen extends StatefulWidget {
  const AttendanceSummaryScreen({super.key});

  @override
  State<AttendanceSummaryScreen> createState() =>
      _AttendanceSummaryScreenState();
}

class _AttendanceSummaryScreenState extends State<AttendanceSummaryScreen> {
  List<AttendanceRecord> _allRecords = [];
  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMonthlyRecords();
  }

  Future<void> _loadMonthlyRecords() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<AttendanceRecord> allRecords = [];

      // Get all days in the selected month
      int daysInMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
      ).day;

      for (int day = 1; day <= daysInMonth; day++) {
        DateTime date = DateTime(
          _selectedMonth.year,
          _selectedMonth.month,
          day,
        );
        if (date.isBefore(DateTime.now().add(const Duration(days: 1)))) {
          try {
            List<AttendanceRecord> dayRecords =
                await FirebaseService.getAttendanceRecords(date);
            allRecords.addAll(dayRecords);
          } catch (e) {
            print('Error loading records for $date: $e');
          }
        }
      }

      setState(() {
        _allRecords = allRecords;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading monthly records: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (picked != null &&
        (picked.year != _selectedMonth.year ||
            picked.month != _selectedMonth.month)) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
      });
      _loadMonthlyRecords();
    }
  }

  Map<String, List<AttendanceRecord>> _getRecordsByUser() {
    Map<String, List<AttendanceRecord>> userRecords = {};

    for (AttendanceRecord record in _allRecords) {
      if (!userRecords.containsKey(record.userId)) {
        userRecords[record.userId] = [];
      }
      userRecords[record.userId]!.add(record);
    }

    return userRecords;
  }

  Map<String, int> _getUserAttendanceDays(List<AttendanceRecord> userRecords) {
    Set<String> checkInDays = {};
    Set<String> checkOutDays = {};

    for (AttendanceRecord record in userRecords) {
      String dateKey = DateFormat('yyyy-MM-dd').format(record.timestamp);
      if (record.type == AttendanceType.checkIn) {
        checkInDays.add(dateKey);
      } else {
        checkOutDays.add(dateKey);
      }
    }

    return {
      'checkInDays': checkInDays.length,
      'checkOutDays': checkOutDays.length,
      'completeDays': checkInDays.intersection(checkOutDays).length,
    };
  }

  Duration _getUserTotalWorkingHours(List<AttendanceRecord> userRecords) {
    Map<String, DateTime?> dailyCheckIn = {};
    Map<String, DateTime?> dailyCheckOut = {};

    // Group records by date
    for (AttendanceRecord record in userRecords) {
      String dateKey = DateFormat('yyyy-MM-dd').format(record.timestamp);

      if (record.type == AttendanceType.checkIn) {
        if (dailyCheckIn[dateKey] == null ||
            record.timestamp.isBefore(dailyCheckIn[dateKey]!)) {
          dailyCheckIn[dateKey] = record.timestamp;
        }
      } else {
        if (dailyCheckOut[dateKey] == null ||
            record.timestamp.isAfter(dailyCheckOut[dateKey]!)) {
          dailyCheckOut[dateKey] = record.timestamp;
        }
      }
    }

    Duration totalDuration = Duration.zero;

    for (String date in dailyCheckIn.keys) {
      if (dailyCheckOut[date] != null) {
        Duration dayDuration = dailyCheckOut[date]!.difference(
          dailyCheckIn[date]!,
        );
        if (dayDuration.isNegative == false) {
          totalDuration += dayDuration;
        }
      }
    }

    return totalDuration;
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<AttendanceRecord>> userRecords = _getRecordsByUser();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Summary'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMonthlyRecords,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: Colors.purple),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: _selectMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Overall Statistics
          if (!_isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOverviewCard(
                              'Total Records',
                              _allRecords.length.toString(),
                              Icons.list_alt,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOverviewCard(
                              'Active Users',
                              userRecords.length.toString(),
                              Icons.people,
                              Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOverviewCard(
                              'Check Ins',
                              _allRecords
                                  .where(
                                    (r) => r.type == AttendanceType.checkIn,
                                  )
                                  .length
                                  .toString(),
                              Icons.login,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildOverviewCard(
                              'Check Outs',
                              _allRecords
                                  .where(
                                    (r) => r.type == AttendanceType.checkOut,
                                  )
                                  .length
                                  .toString(),
                              Icons.logout,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading monthly summary...'),
                      ],
                    ),
                  )
                : userRecords.isEmpty
                ? _buildEmptyState()
                : _buildUserSummaryList(userRecords),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
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
            value,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No attendance data found',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildUserSummaryList(
    Map<String, List<AttendanceRecord>> userRecords,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userRecords.length,
      itemBuilder: (context, index) {
        String userId = userRecords.keys.elementAt(index);
        List<AttendanceRecord> records = userRecords[userId]!;

        // Get user stats
        Map<String, int> attendanceDays = _getUserAttendanceDays(records);
        Duration totalWorkingHours = _getUserTotalWorkingHours(records);

        String userName = records.first.userName;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple,
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Records: ${records.length}'),
                Text('Working Days: ${attendanceDays['completeDays']}'),
                Text(
                  'Total Hours: ${totalWorkingHours.inHours}h ${totalWorkingHours.inMinutes % 60}m',
                ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detailed Statistics:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Check In Days',
                            attendanceDays['checkInDays'].toString(),
                            Icons.login,
                            Colors.green,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Check Out Days',
                            attendanceDays['checkOutDays'].toString(),
                            Icons.logout,
                            Colors.red,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Complete Days',
                            attendanceDays['completeDays'].toString(),
                            Icons.check_circle,
                            Colors.blue,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Total Records',
                            records.length.toString(),
                            Icons.list,
                            Colors.purple,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Working Hours Breakdown
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Working Hours Summary:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Working Hours: ${totalWorkingHours.inHours}h ${totalWorkingHours.inMinutes % 60}m',
                          ),
                          if (attendanceDays['completeDays']! > 0)
                            Text(
                              'Average per Day: ${(totalWorkingHours.inMinutes / attendanceDays['completeDays']! / 60).toStringAsFixed(1)}h',
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Recent Activity
                    const Text(
                      'Recent Activity:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: records.take(10).length,
                        itemBuilder: (context, recordIndex) {
                          AttendanceRecord record = records[recordIndex];
                          return Container(
                            width: 120,
                            margin: const EdgeInsets.only(right: 8),
                            child: Card(
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
                                          size: 14,
                                          color:
                                              record.type ==
                                                  AttendanceType.checkIn
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            record.type ==
                                                    AttendanceType.checkIn
                                                ? 'In'
                                                : 'Out',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color:
                                                  record.type ==
                                                      AttendanceType.checkIn
                                                  ? Colors.green
                                                  : Colors.red,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat(
                                        'dd MMM',
                                      ).format(record.timestamp),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      DateFormat(
                                        'HH:mm',
                                      ).format(record.timestamp),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
