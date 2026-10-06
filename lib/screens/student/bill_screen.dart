import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/bill_calculator.dart';
import '../../services/firestore_service.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = true;
  String? _errorMessage;

  String _selectedPeriod = '';
  List<Map<String, String>> _availablePeriods = [];

  Map<String, dynamic>? _studentData;
  List<Map<String, dynamic>> _attendanceList = [];
  List<Map<String, dynamic>> _billsList = [];
  Map<String, Map<String, dynamic>> _menusByDay = {};

  StudentBillSummary? _currentBillSummary;

  @override
  void initState() {
    super.initState();
    _selectedPeriod = BillCalculator.getMonthKey(DateTime.now());
    _loadBill();
  }

  Future<void> _loadBill() async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Student is not logged in.';
          _isLoading = false;
        });
        return;
      }

      final studentDoc = await _firestoreService.get('students', user.uid);
      final student = <String, dynamic>{
        'id': user.uid,
        ...?studentDoc,
        'name': (studentDoc?['name']?.toString().isNotEmpty ?? false)
            ? studentDoc!['name']
            : (user.displayName ?? 'Student'),
        'email': (studentDoc?['email']?.toString().isNotEmpty ?? false)
            ? studentDoc!['email']
            : (user.email ?? ''),
      };
      if (student['id'] == null || student['id'].toString().isEmpty) {
        student['id'] = user.uid;
      }

      final attendance = await _firestoreService.getAll('attendance');
      final bills = await _firestoreService.getAll('bills');
      final menus = await _firestoreService.getAll('menus');

      final Map<String, Map<String, dynamic>> menuMap = {};
      for (final m in menus) {
        final day = m['day']?.toString();
        if (day != null && day.isNotEmpty) {
          menuMap[day] = m;
        }
      }

      final periods = BillCalculator.getAvailableBillingPeriods(
        attendance.where((a) {
          final sId = (a['studentId'] ?? a['student_id'] ?? a['userId'] ?? '').toString();
          return sId == user.uid || sId == student['id'];
        }).toList(),
      );

      String activePeriod = _selectedPeriod;
      if (activePeriod.isEmpty || !periods.any((p) => p['key'] == activePeriod)) {
        activePeriod = periods.isNotEmpty ? periods.first['key']! : 'all';
      }

      final summary = BillCalculator.calculateStudentBill(
        student: student,
        attendanceList: attendance,
        billsList: bills,
        menusByDay: menuMap,
        billingPeriod: activePeriod,
      );

      if (!mounted) return;

      setState(() {
        _studentData = student;
        _attendanceList = attendance;
        _billsList = bills;
        _menusByDay = menuMap;
        _availablePeriods = periods;
        _selectedPeriod = activePeriod;
        _currentBillSummary = summary;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load bill: $e';
        _isLoading = false;
      });
    }
  }

  void _onPeriodChanged(String newPeriod) {
    if (newPeriod == _selectedPeriod || _studentData == null) return;

    setState(() {
      _selectedPeriod = newPeriod;
      _currentBillSummary = BillCalculator.calculateStudentBill(
        student: _studentData!,
        attendanceList: _attendanceList,
        billsList: _billsList,
        menusByDay: _menusByDay,
        billingPeriod: newPeriod,
      );
    });
  }

  IconData _getMealIcon(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_rounded;
      case 'lunch':
        return Icons.lunch_dining_rounded;
      case 'dinner':
        return Icons.dinner_dining_rounded;
      default:
        return Icons.restaurant_rounded;
    }
  }

  Color _getMealColor(String meal) {
    switch (meal.toLowerCase()) {
      case 'breakfast':
        return const Color(0xFFD97706);
      case 'lunch':
        return const Color(0xFF0284C7);
      case 'dinner':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF059669);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Mess Bill'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadBill,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final summary = _currentBillSummary;
    if (summary == null) {
      return const Center(child: Text('No billing information available.'));
    }

    final isPaid = summary.status == 'paid';

    return RefreshIndicator(
      onRefresh: _loadBill,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          // Period Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Period:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedPeriod,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      items: _availablePeriods.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['key'],
                          child: Text(
                            p['label'] ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _onPeriodChanged(val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Total Invoice Hero Card
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPaid
                    ? [const Color(0xFF065F46), const Color(0xFF059669)]
                    : [const Color(0xFF991B1B), const Color(0xFFDC2626)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: (isPaid ? const Color(0xFF059669) : const Color(0xFFDC2626))
                      .withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      summary.billingPeriodLabel.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white70,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isPaid ? 'PAID' : 'PAYMENT DUE',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '₹${summary.totalBill.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isPaid
                      ? 'All dues for ${summary.billingPeriodLabel} are fully settled.'
                      : 'Pending amount payable for ${summary.totalMeals} meals consumed.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Bill Calculation Breakdown Card
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
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bill Breakdown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${summary.totalMeals} Meals Total',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _calcRow(
                  meal: 'Breakfast',
                  icon: Icons.free_breakfast_rounded,
                  color: const Color(0xFFD97706),
                  count: summary.breakfastCount,
                  total: summary.breakfastTotal,
                ),
                const SizedBox(height: 12),

                _calcRow(
                  meal: 'Lunch',
                  icon: Icons.lunch_dining_rounded,
                  color: const Color(0xFF0284C7),
                  count: summary.lunchCount,
                  total: summary.lunchTotal,
                ),
                const SizedBox(height: 12),

                _calcRow(
                  meal: 'Dinner',
                  icon: Icons.dinner_dining_rounded,
                  color: const Color(0xFF7C3AED),
                  count: summary.dinnerCount,
                  total: summary.dinnerTotal,
                ),

                const SizedBox(height: 14),

                // Pricing methodology disclaimer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Charges are calculated from your verified attendance and the menu rate configured by the mess manager for each meal.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 24, color: Color(0xFFE2E8F0)),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Calculated',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '₹${summary.totalBill.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isPaid ? const Color(0xFF059669) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Meal Consumption History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Meal Consumption History',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                '${summary.consumptions.length} Logs',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (summary.consumptions.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Center(
                child: Text(
                  'No meals recorded for ${summary.billingPeriodLabel}.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
            ...summary.consumptions.reversed.map((item) {
              final mealColor = _getMealColor(item.meal);

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
                        _getMealIcon(item.meal),
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
                            '${item.meal[0].toUpperCase()}${item.meal.substring(1)} • ${item.date}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.menu,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${item.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
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

  Widget _calcRow({
    required String meal,
    required IconData icon,
    required Color color,
    required int count,
    required double total,
  }) {
    final countLabel = count == 0
        ? '0 meals attended'
        : '$count meal${count > 1 ? 's' : ''} attended';

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                countLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        Text(
          '₹${total.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }
}