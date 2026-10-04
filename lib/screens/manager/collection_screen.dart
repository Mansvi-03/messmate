import 'package:flutter/material.dart';

import '../../services/bill_calculator.dart';
import '../../services/firestore_service.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key});

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  bool _loading = true;
  String _selectedPeriod = '';
  List<Map<String, String>> _availablePeriods = [];

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _bills = [];
  List<Map<String, dynamic>> _attendanceList = [];
  List<Map<String, dynamic>> _menus = [];

  List<StudentBillSummary> _allBills = [];

  @override
  void initState() {
    super.initState();
    _selectedPeriod = BillCalculator.getMonthKey(DateTime.now());
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    setState(() => _loading = true);
    try {
      final students = await _firestoreService.getAll('students');
      final bills = await _firestoreService.getAll('bills');
      final attendance = await _firestoreService.getAll('attendance');
      final menus = await _firestoreService.getAll('menus');

      final periods = BillCalculator.getAvailableBillingPeriods(attendance);

      String activePeriod = _selectedPeriod;
      if (activePeriod.isEmpty || !periods.any((p) => p['key'] == activePeriod)) {
        activePeriod = periods.isNotEmpty ? periods.first['key']! : 'all';
      }

      final computedBills = BillCalculator.calculateAllBills(
        students: students,
        attendanceList: attendance,
        billsList: bills,
        menusList: menus,
        billingPeriod: activePeriod,
      );

      if (!mounted) return;

      setState(() {
        _students = students;
        _bills = bills;
        _attendanceList = attendance;
        _menus = menus;
        _availablePeriods = periods;
        _selectedPeriod = activePeriod;
        _allBills = computedBills;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load collection: $e')),
      );
    }
  }

  void _onPeriodChanged(String newPeriod) {
    if (newPeriod == _selectedPeriod) return;

    setState(() {
      _selectedPeriod = newPeriod;
      _allBills = BillCalculator.calculateAllBills(
        students: _students,
        attendanceList: _attendanceList,
        billsList: _bills,
        menusList: _menus,
        billingPeriod: newPeriod,
      );
    });
  }

  Future<void> _togglePaymentStatus(StudentBillSummary summary) async {
    final newStatus = summary.status == 'paid' ? 'unpaid' : 'paid';
    final periodDocId = '${summary.studentId}_${summary.billingPeriod}';

    try {
      final billData = {
        'id': periodDocId,
        'studentId': summary.studentId,
        'period': summary.billingPeriod,
        'month': summary.billingPeriodLabel,
        'status': newStatus,
        'totalAmount': summary.totalBill,
        'totalMeals': summary.totalMeals,
        'breakfastCount': summary.breakfastCount,
        'breakfastAmount': summary.breakfastTotal,
        'lunchCount': summary.lunchCount,
        'lunchAmount': summary.lunchTotal,
        'dinnerCount': summary.dinnerCount,
        'dinnerAmount': summary.dinnerTotal,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await _firestoreService.add('bills', periodDocId, billData);

      final idx = _bills.indexWhere((b) => b['id'] == periodDocId);
      if (idx >= 0) {
        _bills[idx] = billData;
      } else {
        _bills.add(billData);
      }

      if (!mounted) return;

      setState(() {
        _allBills = _allBills.map((b) {
          if (b.studentId == summary.studentId) {
            return b.copyWith(status: newStatus);
          }
          return b;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${summary.studentName}\'s status updated to ${newStatus.toUpperCase()}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paidBills = _allBills.where((b) => b.status == 'paid').toList();
    final unpaidBills = _allBills.where((b) => b.status != 'paid').toList();

    final double totalCollection = paidBills.fold<double>(0, (sum, b) => sum + b.totalBill);
    final double pendingAmount = unpaidBills.fold<double>(0, (sum, b) => sum + b.totalBill);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCollection,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Period Selector
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.blue),
                          const SizedBox(width: 12),
                          const Text(
                            'Period:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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

                  const SizedBox(height: 16),

                  const Text(
                    'Collection Summary',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 14),

                  _summaryItem(
                    'Total Students',
                    _allBills.length.toString(),
                    Icons.people,
                  ),

                  _summaryItem(
                    'Paid Bills',
                    '${paidBills.length} students',
                    Icons.check_circle,
                    valueColor: Colors.green,
                  ),

                  _summaryItem(
                    'Unpaid Bills',
                    '${unpaidBills.length} students',
                    Icons.pending_actions,
                    valueColor: Colors.red,
                  ),

                  _summaryItem(
                    'Total Collection (Paid)',
                    '₹${totalCollection.toStringAsFixed(2)}',
                    Icons.account_balance_wallet,
                    valueColor: Colors.green.shade800,
                  ),

                  _summaryItem(
                    'Pending Dues (Unpaid)',
                    '₹${pendingAmount.toStringAsFixed(2)}',
                    Icons.money_off,
                    valueColor: Colors.red.shade800,
                  ),

                  const SizedBox(height: 24),

                  // Student Lists
                  const Text(
                    'Student Breakdown',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  ..._allBills.map((summary) {
                    final isPaid = summary.status == 'paid';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isPaid ? Colors.green.shade100 : Colors.red.shade100,
                          child: Icon(
                            isPaid ? Icons.check : Icons.priority_high,
                            color: isPaid ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                        title: Text(
                          summary.studentName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Bill: ₹${summary.totalBill.toStringAsFixed(0)}  •  ${summary.totalMeals} meals',
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isPaid ? Colors.green : Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                          onPressed: () => _togglePaymentStatus(summary),
                          child: Text(
                            isPaid ? 'PAID' : 'UNPAID',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  Widget _summaryItem(
    String title,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: valueColor),
        title: Text(title),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ),
    );
  }
}