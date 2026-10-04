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
      final student = studentDoc ?? {
        'id': user.uid,
        'name': user.displayName ?? 'Student',
        'email': user.email ?? '',
      };

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
        attendance.where((a) => a['studentId'] == user.uid).toList(),
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
        return Icons.free_breakfast;
      case 'lunch':
        return Icons.lunch_dining;
      case 'dinner':
        return Icons.dinner_dining;
      default:
        return Icons.restaurant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bill'),
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
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final summary = _currentBillSummary;
    if (summary == null) {
      return const Center(child: Text('No bill data available.'));
    }

    final isPaid = summary.status == 'paid';

    return RefreshIndicator(
      onRefresh: _loadBill,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Billing Period Selector
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month, color: Colors.blue),
                  const SizedBox(width: 12),
                  const Text(
                    'Billing Period:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedPeriod,
                        items: _availablePeriods.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['key'],
                            child: Text(
                              p['label'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600),
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
          ),

          const SizedBox(height: 12),

          // Status Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPaid ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPaid ? Colors.green : Colors.red,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: isPaid ? Colors.green : Colors.red,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaid ? 'PAID' : 'UNPAID',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green.shade900 : Colors.red.shade900,
                        ),
                      ),
                      Text(
                        isPaid
                            ? 'All dues for ${summary.billingPeriodLabel} are settled.'
                            : 'Pending bill of ₹${summary.totalBill.toStringAsFixed(0)} for ${summary.billingPeriodLabel}.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isPaid ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // R.5.3 Bill Calculation Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bill Calculation (R.5.3)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _calcRow(
                    'Breakfast',
                    summary.breakfastUnitPrice,
                    summary.breakfastCount,
                    summary.breakfastTotal,
                  ),
                  const SizedBox(height: 8),

                  _calcRow(
                    'Lunch',
                    summary.lunchUnitPrice,
                    summary.lunchCount,
                    summary.lunchTotal,
                  ),
                  const SizedBox(height: 8),

                  _calcRow(
                    'Dinner',
                    summary.dinnerUnitPrice,
                    summary.dinnerCount,
                    summary.dinnerTotal,
                  ),

                  const Divider(height: 24, thickness: 1),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bill',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '₹${summary.totalBill.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isPaid ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Total Meals Consumed: ${summary.totalMeals} meals',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // R.5.1 Meal Consumption History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Meal History (R.5.1)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${summary.consumptions.length} meals',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (summary.consumptions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No meals taken in ${summary.billingPeriodLabel}.',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            )
          else
            ...summary.consumptions.reversed.map((item) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade50,
                    child: Icon(
                      _getMealIcon(item.meal),
                      color: Colors.blue.shade800,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    '${item.meal[0].toUpperCase()}${item.meal.substring(1)}  •  ${item.date}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    item.menu,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  trailing: Text(
                    '₹${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _calcRow(String meal, double unitPrice, int count, double total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$meal = ₹${unitPrice.toStringAsFixed(0)} × $count days',
          style: const TextStyle(fontSize: 14),
        ),
        Text(
          '₹${total.toStringAsFixed(0)}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}