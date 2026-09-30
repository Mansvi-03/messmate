import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> _attendance = [];

  bool _isLoading = true;
  String? _errorMessage;

  int _presentCount = 0;
  int _absentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        setState(() {
          _errorMessage = 'Student is not logged in.';
          _isLoading = false;
        });
        return;
      }

      final data = await _firestoreService.getAll('attendance');

      final studentAttendance = data.where((item) {
        return item['studentId'] == user.uid;
      }).toList();

      studentAttendance.sort((a, b) {
        final dateA = a['date']?.toString() ?? '';
        final dateB = b['date']?.toString() ?? '';

        return dateB.compareTo(dateA);
      });

      int present = 0;
      int absent = 0;

      for (final item in studentAttendance) {
        if (item['present'] == true) {
          present++;
        } else {
          absent++;
        }
      }

      if (!mounted) return;

      setState(() {
        _attendance = studentAttendance;
        _presentCount = present;
        _absentCount = absent;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load attendance.';
        _isLoading = false;
      });
    }
  }

  String _formatDate(String date) {
    try {
      final parts = date.split('-');

      if (parts.length != 3) {
        return date;
      }

      final year = parts[0];
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);

      const months = [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];

      return '$day ${months[month]} $year';
    } catch (e) {
      return date;
    }
  }

  double _attendancePercentage() {
    final total = _presentCount + _absentCount;

    if (total == 0) {
      return 0;
    }

    return (_presentCount / total) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(
            fontSize: 16,
          ),
        ),
      );
    }

    if (_attendance.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAttendance,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 200),
            Center(
              child: Text(
                'No attendance records found.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    'Attendance Summary',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _summaryItem(
                        'Present',
                        _presentCount.toString(),
                      ),
                      _summaryItem(
                        'Absent',
                        _absentCount.toString(),
                      ),
                      _summaryItem(
                        'Percentage',
                        '${_attendancePercentage().toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'Attendance Records',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          ..._attendance.map((item) {
            final date = item['date']?.toString() ?? '';
            final mealRaw = item['meal']?.toString() ?? '';
            final isPresent = item['present'] == true;

            final mealName = _formatMeal(mealRaw);
            final timing = _getMealTiming(mealRaw);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  _getMealIcon(mealRaw),
                  size: 28,
                  color: isPresent ? Colors.green : Colors.grey,
                ),
                title: Text(
                  '$mealName • ${_formatDate(date)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  'Mess Timing: $timing',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPresent ? Colors.green : Colors.red,
                    ),
                  ),
                  child: Text(
                    isPresent ? 'Present' : 'Absent',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPresent ? Colors.green.shade800 : Colors.red.shade800,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatMeal(String meal) {
    final m = meal.trim().toLowerCase();
    if (m == 'breakfast') return 'Breakfast';
    if (m == 'lunch') return 'Lunch';
    if (m == 'dinner') return 'Dinner';
    if (m.isEmpty) return 'Meal';
    return m[0].toUpperCase() + m.substring(1);
  }

  String _getMealTiming(String meal) {
    final m = meal.trim().toLowerCase();
    if (m == 'breakfast') return '8:00 AM - 10:00 AM';
    if (m == 'lunch') return '12:30 PM - 2:30 PM';
    if (m == 'dinner') return '7:30 PM - 9:30 PM';
    return 'Mess Hours';
  }

  IconData _getMealIcon(String meal) {
    final m = meal.trim().toLowerCase();
    if (m == 'breakfast') return Icons.free_breakfast;
    if (m == 'lunch') return Icons.lunch_dining;
    if (m == 'dinner') return Icons.dinner_dining;
    return Icons.restaurant;
  }

  Widget _summaryItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(title),
      ],
    );
  }
}