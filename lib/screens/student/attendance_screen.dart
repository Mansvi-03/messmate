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
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
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
        title: const Text('My Attendance'),
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
            fontSize: 15,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }

    if (_attendance.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAttendance,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_busy_rounded,
                      size: 36,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Attendance Records',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Records will appear here once marked by the mess manager.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final percentage = _attendancePercentage();

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          // Attendance Summary Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Attendance Overview',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),

                // Percentage & Stats Row
                Row(
                  children: [
                    // Circular indicator representation
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: percentage >= 75
                            ? const Color(0xFFECFDF5)
                            : (percentage >= 50 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                        border: Border.all(
                          color: percentage >= 75
                              ? const Color(0xFF10B981)
                              : (percentage >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444)),
                          width: 3.5,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: percentage >= 75
                                    ? const Color(0xFF065F46)
                                    : (percentage >= 50 ? const Color(0xFFB45309) : const Color(0xFF991B1B)),
                              ),
                            ),
                            const Text(
                              'Rate',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 20),

                    // Present & Absent Badges
                    Expanded(
                      child: Column(
                        children: [
                          _statTile(
                            label: 'Present Meals',
                            count: _presentCount.toString(),
                            icon: Icons.check_circle_rounded,
                            color: const Color(0xFF059669),
                            bgColor: const Color(0xFFECFDF5),
                          ),
                          const SizedBox(height: 8),
                          _statTile(
                            label: 'Absent Meals',
                            count: _absentCount.toString(),
                            icon: Icons.cancel_rounded,
                            color: const Color(0xFFEF4444),
                            bgColor: const Color(0xFFFEF2F2),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Meal Records',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '${_attendance.length} Total Logs',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ..._attendance.map((item) {
            final date = item['date']?.toString() ?? '';
            final mealRaw = item['meal']?.toString() ?? '';
            final isPresent = item['present'] == true;

            final mealName = _formatMeal(mealRaw);
            final timing = _getMealTiming(mealRaw);
            final mealColor = _getMealColor(mealRaw);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: mealColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getMealIcon(mealRaw),
                      color: mealColor,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$mealName • ${_formatDate(date)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              timing,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isPresent ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isPresent ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          size: 14,
                          color: isPresent ? const Color(0xFF059669) : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPresent ? 'Present' : 'Absent',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isPresent ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statTile({
    required String label,
    required String count,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            count,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
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

  Color _getMealColor(String meal) {
    final m = meal.trim().toLowerCase();
    if (m == 'breakfast') return const Color(0xFFD97706);
    if (m == 'lunch') return const Color(0xFF0284C7);
    if (m == 'dinner') return const Color(0xFF7C3AED);
    return const Color(0xFF059669);
  }

  IconData _getMealIcon(String meal) {
    final m = meal.trim().toLowerCase();
    if (m == 'breakfast') return Icons.free_breakfast_rounded;
    if (m == 'lunch') return Icons.lunch_dining_rounded;
    if (m == 'dinner') return Icons.dinner_dining_rounded;
    return Icons.restaurant_rounded;
  }
}